import asyncdispatch, logging, os, smtp, strutils

include "other.tmpl"

proc sendEmail*(to, subject, body: string) {.async.} =
  let
    smtpAddress = getEnv("SMTP_ADDRESS")
    smtpPort = getEnv("SMTP_PORT").parseInt.Port
    smtpMyAddress = getEnv("SMTP_MY_ADDRESS")
    smtpUsername = getEnv("SMTP_USERNAME")
    smtpPassword = getEnv("SMTP_PASSWORD")
    toList = @[to]
    msg = createMessage(subject, body, toList, @[smtpMyAddress], [
      ("From", smtpMyAddress),
      ("MIME-Version", "1.0"),
      ("Content-Type", "text/plain"),
      ("X-Within-Adtech-Version", "dev")
    ])
  var client = newAsyncSmtp(useSsl = true)
  await client.connect(smtpAddress, smtpPort)
  await client.auth(smtpUsername, smtpPassword)
  await client.sendMail(smtpMyAddress, toList, $msg)
  info "sent email to: ", to, " about: ", subject
  await client.close()

proc sendActivationEmail*(to, token: string) {.async.} =
  let
    baseURL = getEnv("BASE_URL")
    webmasterAddress = getEnv("WEBMASTER_ADDRESS")
  await sendEmail(to, "Your activation token for Within AdTech", genActivationEmail(token, baseURL, webmasterAddress))

