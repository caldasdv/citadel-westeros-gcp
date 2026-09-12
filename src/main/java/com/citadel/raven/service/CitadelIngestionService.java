package com.citadel.raven.service;

import org.springframework.ai.document.Document;
import org.springframework.ai.reader.pdf.PagePdfDocumentReader;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CitadelIngestionService {

    private final VectorStore vectorStore;

    @Value("classpath:citadel-archives/targaryen-lineage-and-dragons.pdf")
    private Resource targaryenParchment;

    public CitadelIngestionService(VectorStore vectorStore) {
        this.vectorStore = vectorStore;
    }

    public int ingestCitadelKnowledge() {
        // 1. Ler o pergaminho da Cidadela (PDF)
        var pdfReader = new PagePdfDocumentReader(targaryenParchment);
        List<Document> rawDocuments = pdfReader.get();

        // 2. Fragmentar a sabedoria em chunks de 500 tokens para preservar contexto
        var textSplitter = new TokenTextSplitter(500, 100, 5, 10000, true);
        List<Document> chunkedKnowledge = textSplitter.apply(rawDocuments);

        // 3. Vetorizar e salvar no PGVector (embeddings gerados via Vertex AI)
        vectorStore.accept(chunkedKnowledge);

        return chunkedKnowledge.size();
    }
}
