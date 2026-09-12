package com.citadel.raven.service;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.vectorstore.QuestionAnswerAdvisor;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.stereotype.Service;

@Service
public class GrandMaesterAdvisorService {

    private final ChatClient ravenChatClient;

    public GrandMaesterAdvisorService(ChatClient.Builder builder, VectorStore citadelVault) {
        String maesterPersona = """
            Você é o Arquimeestre da Cidadela de Vilavelha, conselheiro real de Westeros.
            Responda às dúvidas do Pequeno Conselho com tom solene, sábio e preciso.
            Use APENAS o conhecimento recuperado dos arquivos oficiais da Cidadela fornecidos no contexto.
            Se a resposta não estiver nos arquivos, responda: 'Os pergaminhos da Cidadela silenciam sobre este assunto, meu Senhor.'
            """;

        this.ravenChatClient = builder
                .defaultSystem(maesterPersona)
                .defaultAdvisors(QuestionAnswerAdvisor.builder(citadelVault)
                        .searchRequest(SearchRequest.builder()
                                .topK(3)
                                .similarityThreshold(0.5)
                                .build())
                        .build())
                .build();
    }

    public String consultRaven(String question) {
        return ravenChatClient.prompt()
                .user(question)
                .call()
                .content();
    }
}
