package email

import (
	"crypto/tls"
	"fmt"
	"log"
	"net"
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
	if s.Port == "465" {
		return sendMailTLS(addr, s.Host, auth, s.From, []string{to}, msg)
	}
	return smtp.SendMail(addr, auth, s.From, []string{to}, msg)
}

func sendMailTLS(addr, serverName string, auth smtp.Auth, from string, to []string, msg []byte) error {
	conn, err := tls.DialWithDialer(&net.Dialer{}, "tcp", addr, &tls.Config{
		MinVersion:         tls.VersionTLS12,
		ServerName:         serverName,
		InsecureSkipVerify: false,
	})
	if err != nil {
		return err
	}
	defer conn.Close()

	client, err := smtp.NewClient(conn, serverName)
	if err != nil {
		return err
	}
	defer client.Quit()

	if err := client.Auth(auth); err != nil {
		return err
	}
	if err := client.Mail(from); err != nil {
		return err
	}
	for _, recipient := range to {
		if err := client.Rcpt(recipient); err != nil {
			return err
		}
	}
	writer, err := client.Data()
	if err != nil {
		return err
	}
	if _, err := writer.Write(msg); err != nil {
		_ = writer.Close()
		return err
	}
	return writer.Close()
}
