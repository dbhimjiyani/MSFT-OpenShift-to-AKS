package com.example

import akka.actor.testkit.typed.scaladsl.ActorTestKit
import akka.http.scaladsl.model.StatusCodes
import akka.http.scaladsl.testkit.ScalatestRouteTest
import com.example.models.{AppInfo, HealthStatus, MessageRequest}
import com.example.services.RedisService
import de.heikoseeberger.akkahttpcirce.FailFastCirceSupport._
import org.scalatest.matchers.should.Matchers
import org.scalatest.wordspec.AnyWordSpec

class RoutesSpec extends AnyWordSpec with Matchers with ScalatestRouteTest {

  // Mock Redis service for testing
  class MockRedisService extends RedisService("localhost", 6379) {
    override def ping(): Boolean = true
  }

  val redisService = new MockRedisService()
  val routes = new Routes(redisService, "Test App", "1.0.0", "test").routes

  "The service" should {

    "return health status for GET /health" in {
      Get("/health") ~> routes ~> check {
        status shouldEqual StatusCodes.OK
        val health = responseAs[HealthStatus]
        health.status shouldEqual "healthy"
      }
    }

    "return app info for GET /api/info" in {
      Get("/api/info") ~> routes ~> check {
        status shouldEqual StatusCodes.OK
        val info = responseAs[AppInfo]
        info.app shouldEqual "Test App"
        info.version shouldEqual "1.0.0"
        info.environment shouldEqual "test"
      }
    }

    "return HTML for GET /" in {
      Get("/") ~> routes ~> check {
        status shouldEqual StatusCodes.OK
        contentType.toString should include("text/html")
        responseAs[String] should include("Welcome to Scala Demo App")
      }
    }
  }
}
