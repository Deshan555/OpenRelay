import logging

# Define ANSI escape codes for coloring terminal output
class ColouredFormatter(logging.Formatter):
    grey = "\x1b[38;20m"
    blue = "\x1b[34;20m"
    green = "\x1b[32;20m"
    yellow = "\x1b[33;20m"
    red = "\x1b[31;20m"
    bold_red = "\x1b[31;1m"
    reset = "\x1b[0m"
    
    # Format: [timestamp] [level] message
    format_str = "%(asctime)s - %(levelname)s - %(message)s"

    FORMATS = {
        logging.DEBUG: grey + format_str + reset,
        logging.INFO: blue + format_str + reset,
        logging.WARNING: yellow + format_str + reset,
        logging.ERROR: red + format_str + reset,
        logging.CRITICAL: bold_red + format_str + reset,
        # We can add custom level or map SUCCESS to logging.INFO + some specific check,
        # but to keep it simple and standard, we can register a custom SUCCESS level.
    }

    def format(self, record):
        log_fmt = self.FORMATS.get(record.levelno, self.grey + self.format_str + self.reset)
        
        # Check if it's a custom success check or success in message
        if record.levelno == 25: # Custom SUCCESS level
            log_fmt = self.green + self.format_str + self.reset
            
        formatter = logging.Formatter(log_fmt, datefmt="%Y-%m-%d %H:%M:%S")
        return formatter.format(record)

# Register custom SUCCESS log level
SUCCESS_LEVEL_NUM = 25
logging.addLevelName(SUCCESS_LEVEL_NUM, "SUCCESS")

def success(self, message, *args, **kws):
    if self.isEnabledFor(SUCCESS_LEVEL_NUM):
        self._log(SUCCESS_LEVEL_NUM, message, args, **kws)

logging.Logger.success = success

# Configure and get logger
logger = logging.getLogger("OpenRelay")
logger.setLevel(logging.DEBUG)

# Avoid adding multiple handlers if logger is imported multiple times
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    ch.setFormatter(ColouredFormatter())
    logger.addHandler(ch)
