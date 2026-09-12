package com.citadel.raven.web;

import com.citadel.raven.service.CitadelIngestionService;
import com.citadel.raven.service.GrandMaesterAdvisorService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/small-council")
public class SmallCouncilController {

    private final CitadelIngestionService ingestionService;
    private final GrandMaesterAdvisorService maesterAdvisorService;

    public SmallCouncilController(
            CitadelIngestionService ingestionService,
            GrandMaesterAdvisorService maesterAdvisorService) {
        this.ingestionService = ingestionService;
        this.maesterAdvisorService = maesterAdvisorService;
    }

    @PostMapping("/ingest")
    public String loadArchives() {
        int chunksProcessed = ingestionService.ingestCitadelKnowledge();
        return String.format("Sabedoria processada! %d fragmentos armazenados no Cofre da Cidadela.", chunksProcessed);
    }

    @GetMapping("/consult-raven")
    public String consultRaven(@RequestParam String query) {
        return maesterAdvisorService.consultRaven(query);
    }
}
