package com.pickwise.api;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
@RestController
@RequestMapping("/api/v1/me/password")
public class PasswordController {
    private final AccountService accounts;
    public PasswordController(AccountService accounts) {this.accounts=accounts;}
    public record Input(@NotBlank @Size(min=8,max=128) String currentPassword,
                        @NotBlank @Size(min=8,max=128) String newPassword) {}
    @PutMapping @ResponseStatus(HttpStatus.NO_CONTENT)
    public void change(@RequestHeader(value="Authorization",required=false) String header,@Valid @RequestBody Input body) {
        accounts.changePassword(header,body.currentPassword(),body.newPassword());
    }
}
