package com.example

import akka.http.scaladsl.model.{ContentTypes, HttpEntity, HttpResponse, StatusCodes}
import akka.http.scaladsl.server.Directives._
import akka.http.scaladsl.server.Route
import com.example.models._
import com.example.services.RedisService
import de.heikoseeberger.akkahttpcirce.FailFastCirceSupport._
import io.circe.syntax._

import java.time.Instant
import scala.util.{Failure, Success}

class Routes(
  redisService: RedisService,
  appName: String,
  appVersion: String,
  environment: String
) {

  val routes: Route =
    pathPrefix("health") {
      get {
        val health = HealthStatus("healthy", Instant.now())
        complete(health)
      }
    } ~
    pathPrefix("api") {
      path("info") {
        get {
          val info = AppInfo(appName, appVersion, environment)
          complete(info)
        }
      } ~
      path("messages") {
        get {
          parameters("limit".as[Int].withDefault(10)) { limit =>
            redisService.getMessages(limit) match {
              case Success(messages) =>
                val response = MessagesResponse(messages, messages.size)
                complete(response)
              case Failure(ex) =>
                complete(StatusCodes.InternalServerError, s"Error retrieving messages: ${ex.getMessage}")
            }
          }
        } ~
        post {
          entity(as[MessageRequest]) { request =>
            redisService.addMessage(request.text, request.author) match {
              case Success(message) =>
                complete(StatusCodes.Created, message)
              case Failure(ex) =>
                complete(StatusCodes.InternalServerError, s"Error adding message: ${ex.getMessage}")
            }
          }
        }
      }
    } ~
    path("") {
      get {
        complete(HttpResponse(
          StatusCodes.OK,
          entity = HttpEntity(
            ContentTypes.`text/html(UTF-8)`,
            """<html>
              |<head><title>Scala Demo App</title></head>
              |<body>
              |<h1>Welcome to Scala Demo App</h1>
              |<p>Available endpoints:</p>
              |<ul>
              |  <li>GET /health - Health check</li>
              |  <li>GET /api/info - Application information</li>
              |  <li>GET /api/messages - List messages</li>
              |  <li>POST /api/messages - Add a message</li>
              |</ul>
              |</body>
              |</html>""".stripMargin
          )
        ))
      }
    }
}
