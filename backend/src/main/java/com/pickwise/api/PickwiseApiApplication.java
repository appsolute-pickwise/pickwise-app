package com.pickwise.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@org.springframework.scheduling.annotation.EnableScheduling
@SpringBootApplication
public class PickwiseApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(PickwiseApiApplication.class, args);
	}

}
