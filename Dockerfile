# ==============================================================================
# ESTÁGIO 1: Compilação (Build)
# ==============================================================================
FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /app

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn package -DskipTests

# ==============================================================================
# ESTÁGIO 2: Imagem Final de Execução (Compatível com gRPC / glibc)
# ==============================================================================
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

# Criar usuário sem privilégios de root
RUN addgroup --system citadelgroup && adduser --system maesteruser --ingroup citadelgroup
USER maesteruser

COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8080

ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
