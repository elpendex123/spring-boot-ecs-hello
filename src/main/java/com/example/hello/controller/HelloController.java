package com.example.hello.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HelloController {

    @GetMapping("/hello")
    public Map<String, Object> hello(@RequestParam(defaultValue = "World") String name) {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Hello, " + name + "!");
        response.put("timestamp", LocalDateTime.now().toString());
        response.put("version", "1.0.0");
        return response;
    }

    @GetMapping("/")
    public Map<String, String> root() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "Hello World API");
        return response;
    }
}
