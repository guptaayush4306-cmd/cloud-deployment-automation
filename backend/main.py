
from fastapi import FastAPI

app = FastAPI(
    title="Cloud Deployment Automation",
    description="Automated cloud deployment project"
)

@app.get("/")
def home():
    return {
        "message": "Cloud Deployment Platform is running!"
    }

@app.get("/health")
def health():
    return {
        "status": "healthy"
    }

@app.get("/status")
def status():
    return {
        "application": "Cloud Deployment Automation",
        "environment": "development",
        "deployment": "successful"
    }

