"""Domain errors. main.py turns these into consistent JSON error responses."""


class AppError(Exception):
    status_code = 400
    error = "bad_request"

    def __init__(self, message: str, detail=None):
        super().__init__(message)
        self.message = message
        self.detail = detail


class NotFoundError(AppError):
    status_code = 404
    error = "not_found"


class ConflictError(AppError):
    """The request is valid but not allowed in the resource's current state."""
    status_code = 409
    error = "conflict"


class DeliveryFailed(AppError):
    """Sending failed after approval. The campaign stays 'approved' and can be retried."""
    status_code = 502
    error = "delivery_failed"


class ValidationFailed(AppError):
    status_code = 422
    error = "validation_error"
