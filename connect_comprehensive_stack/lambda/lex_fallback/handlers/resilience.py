"""
Resilience patterns for production Lambda functions.
Includes retry logic, circuit breakers, and error handling.
"""
import time
import functools
import logging
from typing import Callable, Any, Dict
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class TransientError(Exception):
    """Errors that may succeed on retry (timeouts, 5xx responses)."""
    pass


class PermanentError(Exception):
    """Errors that will not succeed on retry (4xx responses, validation errors)."""
    pass


class CircuitBreaker:
    """
    Circuit breaker pattern to prevent cascading failures.
    
    States:
    - CLOSED: Normal operation, requests pass through
    - OPEN: Too many failures, requests fail fast
    - HALF_OPEN: Testing if service recovered
    
    Usage:
        breaker = CircuitBreaker(failure_threshold=5, timeout=60)
        result = breaker.call(external_api_call, arg1, arg2)
    """
    
    def __init__(self, failure_threshold: int = 5, timeout: int = 60, name: str = "default"):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.name = name
        self.failures = 0
        self.last_failure_time: float = 0
        self.state = 'CLOSED'
        self.success_count = 0
        
    def call(self, func: Callable, *args, **kwargs) -> Any:
        """Execute function with circuit breaker protection."""
        if self.state == 'OPEN':
            if time.time() - self.last_failure_time > self.timeout:
                logger.info(f"Circuit breaker {self.name}: Transitioning to HALF_OPEN")
                self.state = 'HALF_OPEN'
                self.success_count = 0
            else:
                raise CircuitOpenError(
                    f"Circuit breaker {self.name} is OPEN. "
                    f"Service unavailable, will retry after {self.timeout}s"
                )
        
        try:
            result = func(*args, **kwargs)
            self.on_success()
            return result
        except Exception as e:
            self.on_failure(e)
            raise
    
    def on_success(self):
        """Handle successful call."""
        if self.state == 'HALF_OPEN':
            self.success_count += 1
            if self.success_count >= 2:  # Require 2 successes to fully close
                logger.info(f"Circuit breaker {self.name}: Transitioning to CLOSED")
                self.state = 'CLOSED'
                self.failures = 0
        elif self.state == 'CLOSED':
            self.failures = max(0, self.failures - 1)  # Decay failure count
    
    def on_failure(self, exception: Exception):
        """Handle failed call."""
        self.failures += 1
        self.last_failure_time = time.time()
        
        if self.state == 'HALF_OPEN':
            logger.warning(f"Circuit breaker {self.name}: Failure in HALF_OPEN, returning to OPEN")
            self.state = 'OPEN'
        elif self.failures >= self.failure_threshold:
            logger.error(
                f"Circuit breaker {self.name}: Opening circuit after {self.failures} failures"
            )
            self.state = 'OPEN'
    
    def get_state(self) -> Dict[str, Any]:
        """Get current circuit breaker state for monitoring."""
        return {
            'name': self.name,
            'state': self.state,
            'failures': self.failures,
            'last_failure': datetime.fromtimestamp(self.last_failure_time).isoformat() if self.last_failure_time else None
        }


class CircuitOpenError(Exception):
    """Raised when circuit breaker is open."""
    pass


def with_retry(
    max_attempts: int = 3,
    backoff_factor: float = 2.0,
    max_delay: int = 30,
    retriable_exceptions: tuple = (TransientError,)
):
    """
    Decorator for automatic retry with exponential backoff.
    
    Args:
        max_attempts: Maximum number of retry attempts
        backoff_factor: Multiplier for delay between retries
        max_delay: Maximum delay between retries in seconds
        retriable_exceptions: Tuple of exceptions that trigger retry
        
    Usage:
        @with_retry(max_attempts=3)
        def call_external_api():
            response = requests.get(url, timeout=5)
            if response.status_code >= 500:
                raise TransientError("API unavailable")
            return response.json()
    """
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                    
                except retriable_exceptions as e:
                    last_exception = e
                    
                    if attempt == max_attempts - 1:
                        logger.error(
                            f"{func.__name__}: All {max_attempts} retry attempts failed. "
                            f"Last error: {str(e)}"
                        )
                        raise
                    
                    # Calculate delay with exponential backoff
                    delay = min(backoff_factor ** attempt, max_delay)
                    
                    logger.warning(
                        f"{func.__name__}: Attempt {attempt + 1}/{max_attempts} failed: {str(e)}. "
                        f"Retrying in {delay:.2f}s..."
                    )
                    
                    time.sleep(delay)
                    
                except PermanentError as e:
                    # Don't retry permanent errors
                    logger.error(f"{func.__name__}: Permanent error, not retrying: {str(e)}")
                    raise
                    
                except Exception as e:
                    # Unknown exceptions - don't retry by default
                    logger.error(f"{func.__name__}: Unexpected error: {str(e)}", exc_info=True)
                    raise
            
            # Should never reach here, but just in case
            if last_exception:
                raise last_exception
                
        return wrapper
    return decorator


def with_timeout(seconds: int):
    """
    Decorator to enforce timeout on function execution.
    Note: This uses signal (Unix only) for true interruption.
    For Lambda, rely on Lambda timeout configuration.
    
    Args:
        seconds: Timeout in seconds
    """
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            # In Lambda, we rely on the Lambda timeout
            # This is more for documentation and local testing
            import signal
            
            def timeout_handler(signum, frame):
                raise TimeoutError(f"{func.__name__} timed out after {seconds}s")
            
            # Set the timeout handler
            signal.signal(signal.SIGALRM, timeout_handler)
            signal.alarm(seconds)
            
            try:
                result = func(*args, **kwargs)
            finally:
                signal.alarm(0)  # Disable the alarm
            
            return result
        return wrapper
    return decorator


# Global circuit breakers for different services
circuit_breaker = CircuitBreaker(failure_threshold=5, timeout=60, name="core_banking_api")
crm_circuit_breaker = CircuitBreaker(failure_threshold=3, timeout=30, name="crm_api")
bedrock_circuit_breaker = CircuitBreaker(failure_threshold=5, timeout=60, name="bedrock_api")


def get_all_circuit_states() -> Dict[str, Dict[str, Any]]:
    """Get state of all circuit breakers for monitoring."""
    return {
        'core_banking': circuit_breaker.get_state(),
        'crm': crm_circuit_breaker.get_state(),
        'bedrock': bedrock_circuit_breaker.get_state()
    }


class RateLimiter:
    """
    Simple rate limiter to prevent overwhelming downstream services.
    
    Usage:
        limiter = RateLimiter(max_calls=100, time_window=60)
        if limiter.allow_request():
            make_api_call()
    """
    
    def __init__(self, max_calls: int, time_window: int):
        self.max_calls = max_calls
        self.time_window = time_window
        self.calls = []
    
    def allow_request(self) -> bool:
        """Check if request is allowed under rate limit."""
        now = time.time()
        
        # Remove old calls outside time window
        self.calls = [call_time for call_time in self.calls if now - call_time < self.time_window]
        
        # Check if under limit
        if len(self.calls) < self.max_calls:
            self.calls.append(now)
            return True
        
        logger.warning(f"Rate limit exceeded: {len(self.calls)}/{self.max_calls} calls in {self.time_window}s")
        return False
    
    def get_stats(self) -> Dict[str, Any]:
        """Get current rate limit statistics."""
        return {
            'calls_in_window': len(self.calls),
            'max_calls': self.max_calls,
            'time_window': self.time_window,
            'utilization': len(self.calls) / self.max_calls
        }


# Example usage
if __name__ == "__main__":
    # Test retry decorator
    @with_retry(max_attempts=3, backoff_factor=2)
    def flaky_function(fail_times=2):
        if flaky_function.counter < fail_times:
            flaky_function.counter += 1
            raise TransientError("Temporary failure")
        return "Success!"
    
    flaky_function.counter = 0
    print(flaky_function())
    
    # Test circuit breaker
    breaker = CircuitBreaker(failure_threshold=2, timeout=5)
    
    def unreliable_service():
        raise TransientError("Service down")
    
    for i in range(5):
        try:
            breaker.call(unreliable_service)
        except (TransientError, CircuitOpenError) as e:
            print(f"Attempt {i + 1}: {e}")
            print(f"Breaker state: {breaker.get_state()}")
