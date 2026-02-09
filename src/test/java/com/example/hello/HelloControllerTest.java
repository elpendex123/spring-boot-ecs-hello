package com.example.hello;

import com.example.hello.controller.HelloController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class HelloControllerTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    public void testHelloEndpoint() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/hello", Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(response.getBody()).containsKey("message");
        assertThat(response.getBody().get("message")).asString().contains("Hello");
    }

    @Test
    public void testHelloWithName() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/hello?name=Enrique", Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(response.getBody().get("message")).isEqualTo("Hello, Enrique!");
    }

    @Test
    public void testRootEndpoint() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/", Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(response.getBody().get("status")).isEqualTo("UP");
    }
}
