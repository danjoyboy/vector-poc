package com.poc.ankle.service

import org.slf4j.LoggerFactory
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.ModelAttribute
import org.springframework.web.bind.annotation.RestController

@RestController
class HealthCheckController {

    private val logger = LoggerFactory.getLogger(this::class.java)

    @GetMapping("/healthcheck")
    fun healthcheck(): Map<String, String> {
        return mapOf("status" to "Healthy!")
    }

    @GetMapping("/gas")
    fun gas(
        @ModelAttribute payload: Payload
    ): Map<String, String> {
        logger.info("11111 incoming payload! $payload")
        return mapOf("person" to payload.toString())
    }
}

data class Payload(
    val type: String = "UNKNOWN",
    val text: String = "",
    val number: Int = 0,
)
