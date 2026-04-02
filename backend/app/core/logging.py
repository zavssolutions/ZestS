import logging
import sys

def configure_logging() -> None:
    # Get the root logger
    root_logger = logging.getLogger()
    
    # Remove existing handlers (to clear uvicorn's defaults if necessary)
    if root_logger.hasHandlers():
        root_logger.handlers.clear()
    
    # Set the root logger's level to INFO
    root_logger.setLevel(logging.INFO)
    
    # Create a StreamHandler that writes to stdout
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging.INFO)
    
    # Create a formatter and add it to the handler
    formatter = logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s")
    handler.setFormatter(formatter)
    
    # Add the handler to the root logger
    root_logger.addHandler(handler)
    
    # Ensure specific app loggers also use the same level
    logging.getLogger("app").setLevel(logging.INFO)
    logging.getLogger("uvicorn.access").setLevel(logging.INFO)
    logging.getLogger("alembic").setLevel(logging.INFO)
    
    print("!!! Logging system aggressively reconfigured to stdout !!!")
