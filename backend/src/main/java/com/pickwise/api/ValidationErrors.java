package com.pickwise.api;
import java.util.Map;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.http.HttpStatus;
@RestControllerAdvice
public class ValidationErrors {
    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotReadableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String,String> invalidJson() {return Map.of("message","JSON 입력을 확인해주세요.");}
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String,String> validation(MethodArgumentNotValidException error) {
        return Map.of("message","입력 정보를 확인해주세요.");
    }
}
