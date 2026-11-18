package com.pickwise.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/me/account")
public class AccountDeletionController {
    private final AccountService accounts;
    public AccountDeletionController(AccountService accounts) { this.accounts=accounts; }
    public record Input(@NotBlank @Size(min=8,max=128) String currentPassword) {}
    @DeleteMapping @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@RequestHeader(value="Authorization",required=false) String header,@Valid @RequestBody Input input) {
        accounts.deleteAccount(header,input.currentPassword());
    }
}
