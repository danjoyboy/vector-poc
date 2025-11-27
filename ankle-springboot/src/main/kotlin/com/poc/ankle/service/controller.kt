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
        @ModelAttribute person: Person
    ): Map<String, String> {
        logger.info("11111 incoming gas! $person")
        return mapOf("person" to person.toString())
    }
}

data class Person(
    val name: String = "",
    val age: Int = 0,
)
