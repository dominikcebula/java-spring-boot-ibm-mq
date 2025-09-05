FROM maven:3.9-eclipse-temurin-21 AS builder

COPY . /build

WORKDIR /build

RUN --mount=type=cache,target=/root/.m2 mvn clean install

FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=builder /build/target/message-producer-*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
