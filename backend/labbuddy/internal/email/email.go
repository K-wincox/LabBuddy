package email

import (
	"fmt"
	"log"
	"net/smtp"
)

type Sender struct {
	Mode     string
	Host     string
	Port     string
	User     string
	Password string
	From     string
}

func (s Sender) SendVerificationCode(to, purpose, code string) error {
	if s.Mode != "smtp" {
		log.Printf("[email:log] to=%s purpose=%s code=%s", to, purpose, code)
		return nil
	}
	if s.Host == "" || s.Port == "" || s.User == "" || s.Password == "" || s.From == "" {
		return fmt.Errorf("smtp mode requires SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD and SMTP_FROM")
	}

	subject := "LabBuddy verification code"
	body := fmt.Sprintf("Your LabBuddy verification code is: %s\n\nThis code is valid for a short time. If you did not request it, ignore this email.\n", code)
	msg := []byte("To: " + to + "\r\n" +
		"From: " + s.From + "\r\n" +
		"Subject: " + subject + "\r\n" +
		"Content-Type: text/plain; charset=UTF-8\r\n" +
		"\r\n" + body)

	addr := s.Host + ":" + s.Port
	auth := smtp.PlainAuth("", s.User, s.Password, s.Host)
	return smtp.SendMail(addr, auth, s.From, []string{to}, msg)
}
