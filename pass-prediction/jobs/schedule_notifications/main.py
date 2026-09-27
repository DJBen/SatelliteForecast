"""Entrypoint; deployment stages the shared functions/common package alongside it."""
from common.notification_scheduler import main

if __name__ == '__main__':
    main()
