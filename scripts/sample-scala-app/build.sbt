name := "scala-demo-app"
version := "1.0.0"
scalaVersion := "2.13.12"

lazy val akkaHttpVersion = "10.5.3"
lazy val akkaVersion = "2.8.5"

libraryDependencies ++= Seq(
  "com.typesafe.akka" %% "akka-http" % akkaHttpVersion,
  "com.typesafe.akka" %% "akka-actor-typed" % akkaVersion,
  "com.typesafe.akka" %% "akka-stream" % akkaVersion,
  "io.circe" %% "circe-core" % "0.14.6",
  "io.circe" %% "circe-generic" % "0.14.6",
  "io.circe" %% "circe-parser" % "0.14.6",
  "de.heikoseeberger" %% "akka-http-circe" % "1.39.2",
  "redis.clients" % "jedis" % "5.1.0",
  "ch.qos.logback" % "logback-classic" % "1.4.14",
  
  // Test dependencies
  "com.typesafe.akka" %% "akka-http-testkit" % akkaHttpVersion % Test,
  "com.typesafe.akka" %% "akka-actor-testkit-typed" % akkaVersion % Test,
  "org.scalatest" %% "scalatest" % "3.2.17" % Test
)

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) =>
    xs map {_.toLowerCase} match {
      case "services" :: _ => MergeStrategy.filterDistinctLines
      case _ => MergeStrategy.discard
    }
  case "reference.conf" => MergeStrategy.concat
  case _ => MergeStrategy.first
}

assembly / mainClass := Some("com.example.Main")
assembly / assemblyJarName := "scala-app.jar"
