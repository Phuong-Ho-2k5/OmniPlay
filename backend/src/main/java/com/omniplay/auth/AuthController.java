package com.omniplay.auth;

import com.omniplay.dto.request.RegisterRequest;
import com.omniplay.dto.request.LoginRequest;
import com.omniplay.dto.response.TokenPairResponse;
import com.omniplay.dto.response.RegisteredUserResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auth")
public class AuthController {
    private final AuthService auth;

    public AuthController(AuthService auth) { this.auth = auth; }

    @PostMapping("/register")
    public ResponseEntity<RegisteredUserResponse> register(@RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(auth.register(request));
    }

    @PostMapping("/login")
    public TokenPairResponse login(@RequestBody LoginRequest request) {
        return auth.login(request);
    }
}
