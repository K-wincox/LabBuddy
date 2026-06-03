package config

import (
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	AppEnv              string
	HTTPAddr            string
	DatabaseURL         string
	JWTAccessSecret     string
	JWTRefreshSecret    string
	AccessTokenTTL      time.Duration
	RefreshTokenTTL     time.Duration
	VerificationCodeTTL time.Duration
	EmailMode           string
	SMTPHost            string
	SMTPPort            string
	SMTPUser            string
	SMTPPassword        string
	SMTPFrom            string
}

func Load() Config {
	_ = godotenv.Load()

	return Config{
		AppEnv:              get("APP_ENV", "development"),
		HTTPAddr:            get("HTTP_ADDR", ":8088"),
		DatabaseURL:         mustGet("DATABASE_URL"),
		JWTAccessSecret:     mustGet("JWT_ACCESS_SECRET"),
		JWTRefreshSecret:    mustGet("JWT_REFRESH_SECRET"),
		AccessTokenTTL:      time.Duration(getInt("ACCESS_TOKEN_TTL_MINUTES", 30)) * time.Minute,
		RefreshTokenTTL:     time.Duration(getInt("REFRESH_TOKEN_TTL_HOURS", 720)) * time.Hour,
		VerificationCodeTTL: time.Duration(getInt("VERIFICATION_CODE_TTL_MINUTES", 10)) * time.Minute,
		EmailMode:           get("EMAIL_MODE", "log"),
		SMTPHost:            get("SMTP_HOST", ""),
		SMTPPort:            get("SMTP_PORT", "587"),
		SMTPUser:            get("SMTP_USER", ""),
		SMTPPassword:        get("SMTP_PASSWORD", ""),
		SMTPFrom:            get("SMTP_FROM", ""),
	}
}

func get(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func mustGet(key string) string {
	v := os.Getenv(key)
	if v == "" {
		panic("missing required env: " + key)
	}
	return v
}

func getInt(key string, fallback int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return v
}
