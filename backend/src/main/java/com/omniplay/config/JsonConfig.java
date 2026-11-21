package com.omniplay.config;

import org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tools.jackson.databind.cfg.CoercionAction;
import tools.jackson.databind.cfg.CoercionInputShape;

@Configuration
public class JsonConfig {
    @Bean
    JsonMapperBuilderCustomizer strictStringInputs() {
        return builder -> builder.withCoercionConfig(String.class, config -> {
            for (var shape : new CoercionInputShape[] {CoercionInputShape.Integer, CoercionInputShape.Float,
                    CoercionInputShape.Boolean, CoercionInputShape.Array, CoercionInputShape.Object,
                    CoercionInputShape.EmptyArray, CoercionInputShape.EmptyObject}) {
                config.setCoercion(shape, CoercionAction.Fail);
            }
        });
    }
}
