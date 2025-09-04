package com.dominikcebula.sample.ibm.mq.message.listener;

import org.springframework.jms.annotation.JmsListener;
import org.springframework.stereotype.Component;

@Component
public class MessageListener {
    @JmsListener(destination = "DEV.QUEUE.1")
    public void processMessage(String content) {
        System.out.println("Received message: " + content);
    }
}
