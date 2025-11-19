package com.example

import akka.actor.typed.ActorSystem
import akka.actor.typed.scaladsl.Behaviors
import akka.http.scaladsl.Http
import akka.http.scaladsl.server.Directives._
import com.example.services.RedisService
import org.slf4j.LoggerFactory

import scala.concurrent.duration._
import scala.concurrent.{ExecutionContextExecutor, Future}
import scala.util.{Failure, Success}

object Main {
  private val logger = LoggerFactory.getLogger(this.getClass)

  def main(args: Array[String]): Unit = {
    implicit val system: ActorSystem[Nothing] = ActorSystem(Behaviors.empty, "scala-demo-app")
    implicit val executionContext: ExecutionContextExecutor = system.executionContext

    // Configuration from environment variables
    val host = sys.env.getOrElse("HOST", "0.0.0.0")
    val port = sys.env.getOrElse("PORT", "8080").toInt
    val redisHost = sys.env.getOrElse("REDIS_HOST", "localhost")
    val redisPort = sys.env.getOrElse("REDIS_PORT", "6379").toInt
    
    // ConfigMap values (optional)
    val appName = sys.env.getOrElse("APP_NAME", "Scala Demo App")
    val appVersion = sys.env.getOrElse("APP_VERSION", "1.0.0")
    val environment = sys.env.getOrElse("ENVIRONMENT", "development")

    logger.info(s"Starting $appName v$appVersion in $environment environment")
    logger.info(s"Connecting to Redis at $redisHost:$redisPort")

    // Initialize Redis service
    val redisService = new RedisService(redisHost, redisPort)
    
    // Test Redis connection
    if (redisService.ping()) {
      logger.info("Successfully connected to Redis")
    } else {
      logger.error("Failed to connect to Redis")
    }

    // Create routes
    val routes = new Routes(redisService, appName, appVersion, environment).routes

    // Start HTTP server
    val bindingFuture: Future[Http.ServerBinding] = Http()
      .newServerAt(host, port)
      .bind(routes)

    bindingFuture.onComplete {
      case Success(binding) =>
        val address = binding.localAddress
        logger.info(s"Server online at http://${address.getHostString}:${address.getPort}/")
        
      case Failure(ex) =>
        logger.error(s"Failed to bind HTTP server: ${ex.getMessage}", ex)
        redisService.close()
        system.terminate()
    }

    // Add shutdown hook
    sys.addShutdownHook {
      logger.info("Shutting down...")
      bindingFuture
        .flatMap(_.unbind())
        .onComplete { _ =>
          redisService.close()
          system.terminate()
        }
    }
  }
}
