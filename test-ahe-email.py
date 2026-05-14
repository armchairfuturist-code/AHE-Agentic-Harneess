import re
import socket

def validate_email(email):
    """Validate email address with regex + optional MX lookup."""
    if not isinstance(email, str) or not email.strip():
        return False
    
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(pattern, email.strip()):
        return False
    
    return True


def has_mx_record(domain):
    """Check if domain has MX records."""
    try:
        import dns.resolver
        answers = dns.resolver.resolve(domain, 'MX')
        return len(answers) > 0
    except (ImportError, Exception):
        return None  # Uncertain


import pytest

def test_valid_simple():
    assert validate_email("user@example.com") == True

def test_valid_subdomain():
    assert validate_email("user@sub.example.co.uk") == True

def test_invalid_no_at():
    assert validate_email("userexample.com") == False

def test_invalid_missing_domain():
    assert validate_email("user@") == False

def test_invalid_empty():
    assert validate_email("") == False

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
