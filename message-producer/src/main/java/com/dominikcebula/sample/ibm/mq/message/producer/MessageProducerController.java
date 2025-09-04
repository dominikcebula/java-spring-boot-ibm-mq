package com.dominikcebula.sample.ibm.mq.message.producer;

import lombok.RequiredArgsConstructor;
import org.springframework.jms.core.JmsTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseStatus;

import static org.springframework.http.HttpStatus.ACCEPTED;

@Controller
@RequiredArgsConstructor
public class MessageProducerController {
    private final JmsTemplate jmsTemplate;

    @GetMapping("/api/v1/produce-message")
    @ResponseStatus(ACCEPTED)
    public void produceMessage() {
        jmsTemplate.convertAndSend("DEV.QUEUE.1", "Hello World!");
    }
}
