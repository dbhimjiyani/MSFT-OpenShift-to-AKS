package com.example.models

import io.circe.{Decoder, Encoder}
import io.circe.generic.semiauto._

import java.time.Instant

case class Message(
  id: String,
  text: String,
  author: String,
  timestamp: Instant
)

object Message {
  implicit val messageEncoder: Encoder[Message] = deriveEncoder[Message]
  implicit val messageDecoder: Decoder[Message] = deriveDecoder[Message]
}

case class MessageRequest(
  text: String,
  author: String
)

object MessageRequest {
  implicit val messageRequestEncoder: Encoder[MessageRequest] = deriveEncoder[MessageRequest]
  implicit val messageRequestDecoder: Decoder[MessageRequest] = deriveDecoder[MessageRequest]
}

case class MessagesResponse(
  messages: Seq[Message],
  count: Int
)

object MessagesResponse {
  implicit val messagesResponseEncoder: Encoder[MessagesResponse] = deriveEncoder[MessagesResponse]
  implicit val messagesResponseDecoder: Decoder[MessagesResponse] = deriveDecoder[MessagesResponse]
}

case class HealthStatus(
  status: String,
  timestamp: Instant
)

object HealthStatus {
  implicit val healthStatusEncoder: Encoder[HealthStatus] = deriveEncoder[HealthStatus]
  implicit val healthStatusDecoder: Decoder[HealthStatus] = deriveDecoder[HealthStatus]
}

case class AppInfo(
  app: String,
  version: String,
  environment: String
)

object AppInfo {
  implicit val appInfoEncoder: Encoder[AppInfo] = deriveEncoder[AppInfo]
  implicit val appInfoDecoder: Decoder[AppInfo] = deriveDecoder[AppInfo]
}
