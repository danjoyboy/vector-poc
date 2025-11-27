package com.poc.ankle.application

import org.springframework.boot.actuate.autoconfigure.security.servlet.ManagementWebSecurityAutoConfiguration
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.autoconfigure.data.redis.RedisAutoConfiguration
import org.springframework.boot.autoconfigure.mongo.MongoAutoConfiguration
import org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration
import org.springframework.boot.autoconfigure.security.servlet.SecurityFilterAutoConfiguration
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration
import org.springframework.boot.runApplication
import org.springframework.context.annotation.ComponentScan

@SpringBootApplication(exclude = [
	MongoAutoConfiguration::class,
	RedisAutoConfiguration::class,
	UserDetailsServiceAutoConfiguration::class,
	SecurityAutoConfiguration::class,
	SecurityFilterAutoConfiguration::class,
	ManagementWebSecurityAutoConfiguration::class
])
@ComponentScan(basePackages = ["com.poc.ankle"])
class PocAnkleBackendApplication

fun main(args: Array<String>) {
	runApplication<PocAnkleBackendApplication>(*args)
}
