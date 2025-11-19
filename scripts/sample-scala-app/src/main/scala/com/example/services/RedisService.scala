package com.example.services

import com.example.models.Message
import io.circe.parser.decode
import io.circe.syntax._
import redis.clients.jedis.{Jedis, JedisPool, JedisPoolConfig}
import org.slf4j.LoggerFactory

import scala.util.{Try, Success, Failure}
import java.time.Instant

class RedisService(host: String, port: Int) {
  private val logger = LoggerFactory.getLogger(this.getClass)
  private val poolConfig = new JedisPoolConfig()
  poolConfig.setMaxTotal(10)
  poolConfig.setMaxIdle(5)
  poolConfig.setMinIdle(1)
  
  private val pool = new JedisPool(poolConfig, host, port)
  
  private val MESSAGES_KEY = "messages"
  private val MESSAGE_COUNTER_KEY = "message:counter"

  def addMessage(text: String, author: String): Try[Message] = {
    var jedis: Jedis = null
    try {
      jedis = pool.getResource
      val id = jedis.incr(MESSAGE_COUNTER_KEY).toString
      val message = Message(
        id = id,
        text = text,
        author = author,
        timestamp = Instant.now()
      )
      
      jedis.lpush(MESSAGES_KEY, message.asJson.noSpaces)
      logger.info(s"Added message with ID: $id")
      Success(message)
    } catch {
      case e: Exception =>
        logger.error("Error adding message to Redis", e)
        Failure(e)
    } finally {
      if (jedis != null) jedis.close()
    }
  }

  def getMessages(limit: Int = 10): Try[Seq[Message]] = {
    var jedis: Jedis = null
    try {
      jedis = pool.getResource
      val messagesJson = jedis.lrange(MESSAGES_KEY, 0, limit - 1)
      
      import scala.jdk.CollectionConverters._
      val messages = messagesJson.asScala.flatMap { json =>
        decode[Message](json).toOption
      }.toSeq
      
      logger.info(s"Retrieved ${messages.size} messages")
      Success(messages)
    } catch {
      case e: Exception =>
        logger.error("Error retrieving messages from Redis", e)
        Failure(e)
    } finally {
      if (jedis != null) jedis.close()
    }
  }

  def ping(): Boolean = {
    var jedis: Jedis = null
    try {
      jedis = pool.getResource
      val response = jedis.ping()
      response == "PONG"
    } catch {
      case e: Exception =>
        logger.error("Error pinging Redis", e)
        false
    } finally {
      if (jedis != null) jedis.close()
    }
  }

  def close(): Unit = {
    logger.info("Closing Redis connection pool")
    pool.close()
  }
}
