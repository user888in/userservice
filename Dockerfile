# ============================================================
# STAGE 1: Build
# Use full JDK + Maven to compile and package
# This stage is DISCARDED after build — never goes to prod
# ============================================================
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

# Copy Maven wrapper first (separate layer — cached if unchanged)
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./

# Download dependencies FIRST (separate layer)
# This layer is cached as long as pom.xml doesn't change
# CI builds go from 3 min → 20 seconds after first run
RUN ./mvnw dependency:go-offline -B

# Now copy source code and build
COPY src ./src
RUN ./mvnw clean package -DskipTests -B

# Extract layers for optimized Docker caching (Spring Boot 3+)
RUN java -Djarmode=layertools \
    -jar target/userservice-0.0.1-SNAPSHOT.jar extract \
    --destination target/extracted

# ============================================================
# STAGE 2: Runtime
# Minimal JRE only — no compiler, no Maven, nothing extra
# This is the image that actually runs in production
# ============================================================
FROM eclipse-temurin:21-jre-alpine AS runtime

WORKDIR /app

# Security: create non-root user to run the app
# NEVER run production apps as root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only the extracted layers from builder stage
# Order matters — least-changed layers first (best cache utilization)
COPY --from=builder /app/target/extracted/dependencies/ ./
COPY --from=builder /app/target/extracted/spring-boot-loader/ ./
COPY --from=builder /app/target/extracted/snapshot-dependencies/ ./
COPY --from=builder /app/target/extracted/application/ ./

# Switch to non-root user
USER appuser

# Document which port the app uses (doesn't actually publish it)
EXPOSE 8080

# Health check — Docker and orchestrators use this
# Checks every 30s, 3 failures = container marked unhealthy
HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=60s \
            --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

# JVM flags tuned for containers
# -XX:+UseContainerSupport → JVM respects Docker memory limits
# -XX:MaxRAMPercentage     → Use max 75% of container RAM
# -Djava.security.egd     → Faster startup (entropy source)
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -Djava.security.egd=file:/dev/./urandom"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]