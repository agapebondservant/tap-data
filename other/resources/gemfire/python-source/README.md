# DEPLOYING WAN REPLICATION DEMO PP

NOTE:
* Currently requires **cluster-admin** privileges to set up.
* Assumes that a Learning Center Portal already exists.


* Launch dashboard:
```
pipenv install
pipenv shell
python -m streamlit run app/dashboard.py --logger.level=info
```

### Build Docker Containers for Apps
```
docker build -t oawofolu/demo-dashboard .
docker push oawofolu/demo-dashboard
```

#### Install Oracle Client Libraries
https://www.oracle.com/database/technologies/instant-client/macos-intel-x86-downloads.html

### Deploy Apps to Kubernetes
```
kubectl create deployment primary-dashboard -l dashboard=primary --image=oawofolu/demo-dashboard  -- streamlit run app/dashboard.py primary --logger.level=info
kubectl expose deployment primary-dashboard --port=8080 --target-port=8501 --name=primary-dashboard-svc --type=LoadBalancer
kubectl create deployment secondary-dashboard -l dashboard=secondary --image=oawofolu/demo-dashboard  -- streamlit run app/dashboard.py secondary --logger.level=info
kubectl expose deployment secondary-dashboard --port=8080 --target-port=8501 --name=secondary-dashboard-svc --type=LoadBalaner


watch kubectl get deployment -l dashboard
# (NOTE: If on AWS, change the timeout settings for the LoadBalancers to 3600)
```

#### Test Dashboard locally
```
rm -rf $(pipenv --venv)
python3 -m pip install cx_Oracle --upgrade --user
pipenv install
pipenv shell
ISTIO_HOST=35.227.104.221 python -m streamlit run app/dashboard.py 'primary'
```

#### Sample Test Gemfire Adhoc query
```
python -m app.random_claim_generator -1 -1 http://35.227.104.221:7070/gemfire-api/v1/claims
```
