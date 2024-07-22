# For more information, please refer to https://aka.ms/vscode-docker-python
FROM freistli/docaihub:v1.0.5

EXPOSE 8000

ARG CACHEBUST=1

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

WORKDIR /app
COPY . /app

USER appuser

# During debugging, this entry point will be overridden. For more information, please refer to https://aka.ms/vscode-docker-python-debug
# CMD ["gunicorn", "--bind", "0.0.0.0:8000", "-k", "uvicorn.workers.UvicornWorker", "main:app"]
# CMD ["uvicorn", "--host", "0.0.0.0", "main:app"]
CMD ["./LinuxAdvRAGSvc"]
