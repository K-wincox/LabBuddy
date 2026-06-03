package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"regexp"
	"strings"
	"time"

	"labbuddy/internal/config"
	"labbuddy/internal/db"
	"labbuddy/internal/email"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

const (
	codePurposeRegister = "register"
	codePurposeLogin    = "login"
)

var emailRe = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

type app struct {
	cfg    config.Config
	pool   *pgxpool.Pool
	sender email.Sender
}

type errorResponse struct {
	Error string `json:"error"`
}

type userResponse struct {
	ID            string `json:"id"`
	Email         string `json:"email"`
	EmailVerified bool   `json:"emailVerified"`
	DisplayName   string `json:"displayName"`
	LabName       string `json:"labName"`
}

type authResponse struct {
	User         userResponse `json:"user"`
	AccessToken  string       `json:"accessToken"`
	RefreshToken string       `json:"refreshToken"`
	ExpiresIn    int64        `json:"expiresIn"`
}

func main() {
	cfg := config.Load()
	ctx := context.Background()

	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect database: %v", err)
	}
	defer pool.Close()

	if err := db.Migrate(ctx, pool, "migrations"); err != nil {
		log.Fatalf("migrate database: %v", err)
	}

	a := &app{
		cfg:  cfg,
		pool: pool,
		sender: email.Sender{
			Mode:     cfg.EmailMode,
			Host:     cfg.SMTPHost,
			Port:     cfg.SMTPPort,
			User:     cfg.SMTPUser,
			Password: cfg.SMTPPassword,
			From:     cfg.SMTPFrom,
		},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", a.health)
	mux.HandleFunc("POST /api/v1/auth/register/start", a.registerStart)
	mux.HandleFunc("POST /api/v1/auth/register/verify", a.registerVerify)
	mux.HandleFunc("POST /api/v1/auth/login/password", a.loginPassword)
	mux.HandleFunc("POST /api/v1/auth/login/code/start", a.loginCodeStart)
	mux.HandleFunc("POST /api/v1/auth/login/code/verify", a.loginCodeVerify)
	mux.HandleFunc("POST /api/v1/auth/refresh", a.refresh)
	mux.HandleFunc("POST /api/v1/auth/logout", a.logout)
	mux.HandleFunc("GET /api/v1/me", a.me)

	log.Printf("LabBuddy API listening on %s", cfg.HTTPAddr)
	if err := http.ListenAndServe(cfg.HTTPAddr, a.withCORS(mux)); err != nil {
		log.Fatal(err)
	}
}

func (a *app) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *app) registerStart(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	emailAddr := normalizeEmail(req.Email)
	if !validEmail(emailAddr) {
		writeErr(w, http.StatusBadRequest, "invalid_email")
		return
	}
	if len(req.Password) < 8 {
		writeErr(w, http.StatusBadRequest, "password_too_short")
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "password_hash_failed")
		return
	}

	var verified bool
	err = a.pool.QueryRow(r.Context(), `
INSERT INTO users (email, password_hash)
VALUES ($1, $2)
ON CONFLICT (email) DO UPDATE
SET password_hash = CASE WHEN users.email_verified = false THEN EXCLUDED.password_hash ELSE users.password_hash END,
    updated_at = now()
RETURNING email_verified`, emailAddr, string(passwordHash)).Scan(&verified)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "register_failed")
		return
	}
	if verified {
		writeErr(w, http.StatusConflict, "email_already_registered")
		return
	}

	if err := a.createAndSendCode(r.Context(), emailAddr, codePurposeRegister); err != nil {
		writeErr(w, http.StatusInternalServerError, "send_code_failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "verification_code_sent"})
}

func (a *app) registerVerify(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email      string `json:"email"`
		Code       string `json:"code"`
		DeviceName string `json:"deviceName"`
		DeviceID   string `json:"deviceId"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	emailAddr := normalizeEmail(req.Email)
	if !validEmail(emailAddr) || !validCode(req.Code) {
		writeErr(w, http.StatusBadRequest, "invalid_request")
		return
	}
	if err := a.verifyCode(r.Context(), emailAddr, codePurposeRegister, req.Code); err != nil {
		writeErr(w, http.StatusUnauthorized, err.Error())
		return
	}

	var user userResponse
	err := a.pool.QueryRow(r.Context(), `
UPDATE users
SET email_verified = true, last_login_at = now(), updated_at = now()
WHERE email = $1 AND status = 'active'
RETURNING id::text, email, email_verified`, emailAddr).Scan(&user.ID, &user.Email, &user.EmailVerified)
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "user_not_found")
		return
	}
	if _, err := a.pool.Exec(r.Context(), `
INSERT INTO user_profiles (user_id, display_name, lab_name)
VALUES ($1, $2, $3)
ON CONFLICT (user_id) DO NOTHING`, user.ID, "未命名用户", "个人工作区"); err != nil {
		writeErr(w, http.StatusInternalServerError, "profile_init_failed")
		return
	}
	user.DisplayName = "未命名用户"
	user.LabName = "个人工作区"

	resp, err := a.issueAuth(r.Context(), user, req.DeviceName, req.DeviceID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "issue_token_failed")
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (a *app) loginPassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email      string `json:"email"`
		Password   string `json:"password"`
		DeviceName string `json:"deviceName"`
		DeviceID   string `json:"deviceId"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	emailAddr := normalizeEmail(req.Email)
	if !validEmail(emailAddr) || req.Password == "" {
		writeErr(w, http.StatusBadRequest, "invalid_request")
		return
	}

	var passwordHash string
	var user userResponse
	err := a.pool.QueryRow(r.Context(), `
SELECT u.id::text, u.email, u.email_verified, COALESCE(p.display_name, ''), COALESCE(p.lab_name, ''), u.password_hash
FROM users u
LEFT JOIN user_profiles p ON p.user_id = u.id
WHERE u.email = $1 AND u.status = 'active'`, emailAddr).
		Scan(&user.ID, &user.Email, &user.EmailVerified, &user.DisplayName, &user.LabName, &passwordHash)
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusUnauthorized, "invalid_credentials")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "login_failed")
		return
	}
	if !user.EmailVerified {
		writeErr(w, http.StatusForbidden, "email_not_verified")
		return
	}
	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		writeErr(w, http.StatusUnauthorized, "invalid_credentials")
		return
	}
	_, _ = a.pool.Exec(r.Context(), "UPDATE users SET last_login_at = now(), updated_at = now() WHERE id = $1", user.ID)

	resp, err := a.issueAuth(r.Context(), user, req.DeviceName, req.DeviceID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "issue_token_failed")
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (a *app) loginCodeStart(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	emailAddr := normalizeEmail(req.Email)
	if !validEmail(emailAddr) {
		writeErr(w, http.StatusBadRequest, "invalid_email")
		return
	}

	var exists bool
	if err := a.pool.QueryRow(r.Context(), `
SELECT EXISTS (
    SELECT 1 FROM users
    WHERE email = $1 AND email_verified = true AND status = 'active'
)`, emailAddr).Scan(&exists); err != nil {
		writeErr(w, http.StatusInternalServerError, "lookup_failed")
		return
	}
	if !exists {
		writeErr(w, http.StatusNotFound, "email_not_registered")
		return
	}
	if err := a.createAndSendCode(r.Context(), emailAddr, codePurposeLogin); err != nil {
		writeErr(w, http.StatusInternalServerError, "send_code_failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "verification_code_sent"})
}

func (a *app) loginCodeVerify(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email      string `json:"email"`
		Code       string `json:"code"`
		DeviceName string `json:"deviceName"`
		DeviceID   string `json:"deviceId"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	emailAddr := normalizeEmail(req.Email)
	if !validEmail(emailAddr) || !validCode(req.Code) {
		writeErr(w, http.StatusBadRequest, "invalid_request")
		return
	}
	if err := a.verifyCode(r.Context(), emailAddr, codePurposeLogin, req.Code); err != nil {
		writeErr(w, http.StatusUnauthorized, err.Error())
		return
	}

	user, err := a.getUserByEmail(r.Context(), emailAddr)
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "user_not_found")
		return
	}
	_, _ = a.pool.Exec(r.Context(), "UPDATE users SET last_login_at = now(), updated_at = now() WHERE id = $1", user.ID)

	resp, err := a.issueAuth(r.Context(), user, req.DeviceName, req.DeviceID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "issue_token_failed")
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (a *app) refresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refreshToken"`
	}
	if !readJSON(w, r, &req) {
		return
	}
	claims, err := a.parseToken(req.RefreshToken, a.cfg.JWTRefreshSecret, "refresh")
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "invalid_refresh_token")
		return
	}
	sessionID, _ := claims["sid"].(string)
	userID, _ := claims["sub"].(string)
	if sessionID == "" || userID == "" {
		writeErr(w, http.StatusUnauthorized, "invalid_refresh_token")
		return
	}

	var exists bool
	err = a.pool.QueryRow(r.Context(), `
SELECT EXISTS (
    SELECT 1 FROM auth_sessions
    WHERE id = $1
      AND user_id = $2
      AND refresh_token_hash = $3
      AND revoked_at IS NULL
      AND expires_at > now()
)`, sessionID, userID, shaToken(req.RefreshToken)).Scan(&exists)
	if err != nil || !exists {
		writeErr(w, http.StatusUnauthorized, "invalid_refresh_token")
		return
	}

	access, err := a.signToken(userID, "", "access", a.cfg.JWTAccessSecret, a.cfg.AccessTokenTTL)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "issue_token_failed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"accessToken": access,
		"expiresIn":   int64(a.cfg.AccessTokenTTL.Seconds()),
	})
}

func (a *app) logout(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refreshToken"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.RefreshToken != "" {
		if claims, err := a.parseToken(req.RefreshToken, a.cfg.JWTRefreshSecret, "refresh"); err == nil {
			if sessionID, _ := claims["sid"].(string); sessionID != "" {
				_, _ = a.pool.Exec(r.Context(), "UPDATE auth_sessions SET revoked_at = now() WHERE id = $1", sessionID)
			}
		}
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "logged_out"})
}

func (a *app) me(w http.ResponseWriter, r *http.Request) {
	userID, ok := a.requireAccess(w, r)
	if !ok {
		return
	}
	user, err := a.getUserByID(r.Context(), userID)
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "user_not_found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"user": user})
}

func (a *app) createAndSendCode(ctx context.Context, emailAddr, purpose string) error {
	code, err := randomCode()
	if err != nil {
		return err
	}
	_, err = a.pool.Exec(ctx, `
INSERT INTO email_verification_codes (email, purpose, code_hash, expires_at)
VALUES ($1, $2, $3, $4)`, emailAddr, purpose, shaToken(code), time.Now().Add(a.cfg.VerificationCodeTTL))
	if err != nil {
		return err
	}
	return a.sender.SendVerificationCode(emailAddr, purpose, code)
}

func (a *app) verifyCode(ctx context.Context, emailAddr, purpose, code string) error {
	tx, err := a.pool.Begin(ctx)
	if err != nil {
		return errors.New("code_check_failed")
	}
	defer tx.Rollback(ctx)

	var id string
	var codeHash string
	var attempts int
	var expiresAt time.Time
	err = tx.QueryRow(ctx, `
SELECT id::text, code_hash, attempt_count, expires_at
FROM email_verification_codes
WHERE email = $1 AND purpose = $2 AND consumed_at IS NULL
ORDER BY created_at DESC
LIMIT 1
FOR UPDATE`, emailAddr, purpose).Scan(&id, &codeHash, &attempts, &expiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return errors.New("code_not_found")
	}
	if err != nil {
		return errors.New("code_check_failed")
	}
	if attempts >= 5 {
		return errors.New("too_many_attempts")
	}
	if time.Now().After(expiresAt) {
		return errors.New("code_expired")
	}
	if codeHash != shaToken(code) {
		_, _ = tx.Exec(ctx, "UPDATE email_verification_codes SET attempt_count = attempt_count + 1 WHERE id = $1", id)
		_ = tx.Commit(ctx)
		return errors.New("invalid_code")
	}
	if _, err := tx.Exec(ctx, "UPDATE email_verification_codes SET consumed_at = now() WHERE id = $1", id); err != nil {
		return errors.New("code_check_failed")
	}
	if err := tx.Commit(ctx); err != nil {
		return errors.New("code_check_failed")
	}
	return nil
}

func (a *app) issueAuth(ctx context.Context, user userResponse, deviceName, deviceID string) (authResponse, error) {
	sessionID := uuid.NewString()
	refresh, err := a.signToken(user.ID, sessionID, "refresh", a.cfg.JWTRefreshSecret, a.cfg.RefreshTokenTTL)
	if err != nil {
		return authResponse{}, err
	}
	access, err := a.signToken(user.ID, "", "access", a.cfg.JWTAccessSecret, a.cfg.AccessTokenTTL)
	if err != nil {
		return authResponse{}, err
	}
	_, err = a.pool.Exec(ctx, `
INSERT INTO auth_sessions (id, user_id, refresh_token_hash, device_name, device_id, expires_at)
VALUES ($1, $2, $3, $4, $5, $6)`, sessionID, user.ID, shaToken(refresh), deviceName, deviceID, time.Now().Add(a.cfg.RefreshTokenTTL))
	if err != nil {
		return authResponse{}, err
	}
	return authResponse{
		User:         user,
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    int64(a.cfg.AccessTokenTTL.Seconds()),
	}, nil
}

func (a *app) signToken(userID, sessionID, typ, secret string, ttl time.Duration) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"sub": userID,
		"typ": typ,
		"iat": now.Unix(),
		"exp": now.Add(ttl).Unix(),
	}
	if sessionID != "" {
		claims["sid"] = sessionID
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

func (a *app) parseToken(raw, secret, typ string) (jwt.MapClaims, error) {
	token, err := jwt.Parse(raw, func(token *jwt.Token) (any, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return []byte(secret), nil
	})
	if err != nil || !token.Valid {
		return nil, errors.New("invalid_token")
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, errors.New("invalid_token")
	}
	if claimType, _ := claims["typ"].(string); claimType != typ {
		return nil, errors.New("invalid_token_type")
	}
	return claims, nil
}

func (a *app) requireAccess(w http.ResponseWriter, r *http.Request) (string, bool) {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") {
		writeErr(w, http.StatusUnauthorized, "missing_access_token")
		return "", false
	}
	claims, err := a.parseToken(strings.TrimPrefix(auth, "Bearer "), a.cfg.JWTAccessSecret, "access")
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "invalid_access_token")
		return "", false
	}
	userID, _ := claims["sub"].(string)
	if userID == "" {
		writeErr(w, http.StatusUnauthorized, "invalid_access_token")
		return "", false
	}
	return userID, true
}

func (a *app) getUserByEmail(ctx context.Context, emailAddr string) (userResponse, error) {
	var user userResponse
	err := a.pool.QueryRow(ctx, `
SELECT u.id::text, u.email, u.email_verified, COALESCE(p.display_name, ''), COALESCE(p.lab_name, '')
FROM users u
LEFT JOIN user_profiles p ON p.user_id = u.id
WHERE u.email = $1 AND u.email_verified = true AND u.status = 'active'`, emailAddr).
		Scan(&user.ID, &user.Email, &user.EmailVerified, &user.DisplayName, &user.LabName)
	return user, err
}

func (a *app) getUserByID(ctx context.Context, userID string) (userResponse, error) {
	var user userResponse
	err := a.pool.QueryRow(ctx, `
SELECT u.id::text, u.email, u.email_verified, COALESCE(p.display_name, ''), COALESCE(p.lab_name, '')
FROM users u
LEFT JOIN user_profiles p ON p.user_id = u.id
WHERE u.id = $1 AND u.status = 'active'`, userID).
		Scan(&user.ID, &user.Email, &user.EmailVerified, &user.DisplayName, &user.LabName)
	return user, err
}

func randomCode() (string, error) {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func shaToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func normalizeEmail(raw string) string {
	return strings.ToLower(strings.TrimSpace(raw))
}

func validEmail(email string) bool {
	return emailRe.MatchString(email)
}

func validCode(code string) bool {
	if len(code) != 6 {
		return false
	}
	for _, ch := range code {
		if ch < '0' || ch > '9' {
			return false
		}
	}
	return true
}

func readJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	defer r.Body.Close()
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(dst); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid_json")
		return false
	}
	return true
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, errorResponse{Error: msg})
}

func (a *app) withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
