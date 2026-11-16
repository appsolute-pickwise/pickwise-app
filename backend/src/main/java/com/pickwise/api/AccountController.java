package com.pickwise.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AccountController {
    private final AccountService accounts;
    public AccountController(AccountService accounts) { this.accounts = accounts; }
    public record Credentials(@NotBlank @Email @Size(max=254) String email,
                              @NotBlank @Size(min=8,max=128) String password) {}
    @PostMapping("/register") @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public Map<String,String> register(@Valid @RequestBody Credentials body) {
        return accounts.register(body.email(), body.password());
    }
    @PostMapping("/login")
    public Map<String,String> login(@Valid @RequestBody Credentials body) {
        return accounts.login(body.email(), body.password());
    }
    public record Refresh(@NotBlank @Size(max=150) String refreshToken) {}
    @PostMapping("/refresh")
    public Map<String,String> refresh(@Valid @RequestBody Refresh body) { return accounts.refresh(body.refreshToken()); }
    @GetMapping("/me")
    public Map<String,String> me(@RequestHeader(value="Authorization",required=false) String header) { return accounts.me(header); }
    @PostMapping("/logout") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
    public void logout(@RequestHeader(value="Authorization",required=false) String header) {
        accounts.logout(header);
    }
}
