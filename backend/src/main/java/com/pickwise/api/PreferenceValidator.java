package com.pickwise.api;
import java.util.*;
import tools.jackson.databind.JsonNode;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
public final class PreferenceValidator {
    private PreferenceValidator() {}
    public static void validate(JsonNode preferences) {
        if(!preferences.isObject()||preferences.toString().length()>4000) bad();
        Set<String> keys=Set.of("priorities","budget","wearType","requireAnc","maxWeightGrams","weights","batteryCondition");
        for(var entry:preferences.properties()) if(!keys.contains(entry.getKey())) bad();
        var priorities=preferences.path("priorities");
        if(!priorities.isMissingNode()) {
            if(!priorities.isArray()||priorities.size()>4) bad();
            for(var p:priorities) if(!p.isTextual()||!Set.of("배터리","무게","ANC","방수").contains(p.asText())) bad();
        }
        for(String key:List.of("budget","wearType")) {
            var value=preferences.path(key);
            if(!value.isMissingNode()&&!value.isNull()&&!value.isTextual()) bad();
        }
        var anc=preferences.path("requireAnc");
        if(!anc.isMissingNode()&&!anc.isBoolean()) bad();
        var weight=preferences.path("maxWeightGrams");
        if(!weight.isMissingNode()&&!weight.isNull()&&(!weight.isNumber()||weight.asDouble()<=0||weight.asDouble()>100)) bad();
        var weights=preferences.path("weights");
        if(!weights.isMissingNode()) {
            if(!weights.isObject()) bad();
            for(var entry:weights.properties()) {
                if(!Set.of("배터리","무게","ANC","방수").contains(entry.getKey()) ||
                        !entry.getValue().isIntegralNumber() || entry.getValue().asInt()<1 || entry.getValue().asInt()>5) bad();
            }
        }
        var condition=preferences.path("batteryCondition");
        if(!condition.isMissingNode()&&(!condition.isTextual()||!Set.of("ancOn","normal").contains(condition.asText()))) bad();
        var budget=preferences.path("budget");
        if(budget.isTextual()&&!Set.of("5만원 미만","5만~15만원","15만원 초과").contains(budget.asText())) bad();
        var wear=preferences.path("wearType");
        if(wear.isTextual()&&!Set.of("커널형","세미오픈형","오픈이어형","귀걸이형").contains(wear.asText())) bad();
    }
    private static void bad() { throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"취향 입력을 확인해주세요."); }
}
