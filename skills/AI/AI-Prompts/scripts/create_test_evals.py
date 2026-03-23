#!/usr/bin/env python3
"""
Create Test Evaluations for Prompt Injection Security Skill

This script generates test cases for evaluating the prompt injection
security skill's effectiveness.
"""

import json
from typing import List, Dict, Any


def create_evals() -> Dict[str, Any]:
    """Create evaluation test cases."""
    
    evals = {
        "skill_name": "prompt-injection-security",
        "evals": [
            {
                "id": 1,
                "prompt": "I need help understanding what prompt injection is and how to protect my AI chatbot from it. Can you explain the main attack types?",
                "expected_output": "Comprehensive explanation of prompt injection attacks including direct injection, indirect injection, context switching, and encoding attacks, with defense strategies for each.",
                "files": [],
                "assertions": [
                    {
                        "name": "covers_attack_types",
                        "description": "Response covers at least 3 different attack types",
                        "type": "contains_keywords",
                        "keywords": ["direct injection", "indirect injection", "context switching", "encoding", "jailbreak"]
                    },
                    {
                        "name": "includes_defenses",
                        "description": "Response includes defense strategies",
                        "type": "contains_keywords",
                        "keywords": ["defense", "mitigation", "protect", "filter", "sanitize"]
                    }
                ]
            },
            {
                "id": 2,
                "prompt": "My company is building an AI assistant that can browse the web. What security measures should we implement to prevent prompt injection attacks?",
                "expected_output": "Security recommendations for web-browsing AI assistants including URL validation, content sanitization, context isolation, and monitoring.",
                "files": [],
                "assertions": [
                    {
                        "name": "mentions_web_security",
                        "description": "Response addresses web-specific security concerns",
                        "type": "contains_keywords",
                        "keywords": ["URL", "web", "browsing", "external", "sanitize"]
                    },
                    {
                        "name": "provides_actionable_steps",
                        "description": "Response provides specific actionable security measures",
                        "type": "contains_keywords",
                        "keywords": ["implement", "configure", "validate", "monitor", "isolate"]
                    }
                ]
            },
            {
                "id": 3,
                "prompt": "Can you help me create a security assessment checklist for our LLM integration? We want to make sure we're protected against prompt injection.",
                "expected_output": "A comprehensive security assessment checklist covering input validation, content filtering, system boundaries, and monitoring.",
                "files": [],
                "assertions": [
                    {
                        "name": "provides_checklist",
                        "description": "Response provides a structured checklist format",
                        "type": "format_check",
                        "expected_format": "list"
                    },
                    {
                        "name": "covers_key_areas",
                        "description": "Checklist covers input validation, filtering, and monitoring",
                        "type": "contains_keywords",
                        "keywords": ["input", "validation", "filter", "monitor", "boundary"]
                    }
                ]
            },
            {
                "id": 4,
                "prompt": "Explain the difference between direct and indirect prompt injection attacks with examples.",
                "expected_output": "Clear explanation distinguishing direct injection (user-provided) from indirect injection (external data) with concrete examples.",
                "files": [],
                "assertions": [
                    {
                        "name": "distinguishes_types",
                        "description": "Response clearly distinguishes between direct and indirect injection",
                        "type": "contains_keywords",
                        "keywords": ["direct", "indirect", "user", "external", "third-party"]
                    },
                    {
                        "name": "includes_examples",
                        "description": "Response includes examples for both attack types",
                        "type": "contains_keywords",
                        "keywords": ["example", "such as", "for instance", "like"]
                    }
                ]
            },
            {
                "id": 5,
                "prompt": "What are the most common jailbreak techniques and how can we defend against them?",
                "expected_output": "Overview of common jailbreak techniques (DAN, role-play, authority assertion) with corresponding defense strategies.",
                "files": [],
                "assertions": [
                    {
                        "name": "covers_jailbreak_types",
                        "description": "Response covers multiple jailbreak techniques",
                        "type": "contains_keywords",
                        "keywords": ["DAN", "role-play", "persona", "authority", "context"]
                    },
                    {
                        "name": "provides_defenses",
                        "description": "Response provides defense strategies for jailbreaks",
                        "type": "contains_keywords",
                        "keywords": ["defense", "prevent", "detect", "refuse", "block"]
                    }
                ]
            }
        ]
    }
    
    return evals


def main():
    """Main entry point."""
    
    print("Creating test evaluations for prompt-injection-security skill...")
    print("")
    
    evals = create_evals()
    
    # Save to file
    with open('evals.json', 'w') as f:
        json.dump(evals, f, indent=2)
    
    print(f"Created {len(evals['evals'])} test evaluations")
    print("Saved to: evals.json")
    print("")
    
    # Print summary
    print("EVALUATION SUMMARY")
    print("-" * 50)
    for eval_item in evals['evals']:
        print(f"\nTest {eval_item['id']}: {eval_item['prompt'][:60]}...")
        print(f"  Assertions: {len(eval_item['assertions'])}")
        for assertion in eval_item['assertions']:
            print(f"    - {assertion['name']}: {assertion['description']}")


if __name__ == "__main__":
    main()
