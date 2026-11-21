package com.omniplay.config;

import com.omniplay.common.error.ApiErrorWriter;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.auth.AuthAuthenticationEntryPoint;
import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;

@Configuration
public class SecurityConfig {
    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http, ApiErrorWriter errors,
            AuthAuthenticationEntryPoint entryPoint) throws Exception {
        var bearerTokens = new DefaultBearerTokenResolver();
        return http
                .csrf(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .requestCache(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
                        .requestMatchers(HttpMethod.GET, "/actuator/health").permitAll()
                        .requestMatchers(HttpMethod.POST, "/auth/register").permitAll()
                        .requestMatchers(HttpMethod.POST, "/auth/login").permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(handling -> handling
                        .authenticationEntryPoint(entryPoint)
                        .accessDeniedHandler((request, response, exception) ->
                                errors.write(response, ErrorCode.FORBIDDEN)))
                .oauth2ResourceServer(resource -> resource
                        .jwt(jwt -> {})
                        .bearerTokenResolver(request -> {
                            String path = request.getRequestURI().substring(request.getContextPath().length());
                            boolean publicRequest = "GET".equals(request.getMethod()) && "/actuator/health".equals(path)
                                    || "POST".equals(request.getMethod())
                                    && ("/auth/register".equals(path) || "/auth/login".equals(path));
                            return publicRequest ? null : bearerTokens.resolve(request);
                        })
                        .authenticationEntryPoint(entryPoint)
                        .accessDeniedHandler((request, response, exception) -> errors.write(response, ErrorCode.FORBIDDEN)))
                .build();
    }
}
