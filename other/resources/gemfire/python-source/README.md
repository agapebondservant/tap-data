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
docker build -t oawofolu/demo-dashboard other/resources/gemfire/python-source
docker push oawofolu/demo-dashboard
```

### Deploy Apps to Kubernetes
```
kubectl create deployment oracle-primary-dashboard -l dashboard=oracle --image=oawofolu/demo-dashboard  -- streamlit run app/dashboard.py primary oracle
kubectl expose deployment oracle-primary-dashboard --port=8080 --target-port=8501 --name=oracle-primary-dashboard-svc --type=LoadBalancer
kubectl create deployment oracle-secondary-dashboard -l dashboard=oracle --image=oawofolu/demo-dashboard  -- streamlit run app/dashboard.py secondary oracle
kubectl expose deployment oracle-secondary-dashboard --port=8080 --target-port=8501 --name=oracle-secondary-dashboard-svc --type=LoadBalancer

kubectl create deployment mysql-primary-dashboard -l dashboard=mysql --image=oawofolu/demo-dashboard  -- streamlit run app/dashboard.py primary mysql
kubectl expose deployment mysql-primary-dashboard --port=8080 --target-port=8501 --name=mysql-primary-dashboard-svc --type=LoadBalancer
kubectl create deployment mysql-secondary-dashboard -l dashboard=mysql --image=oawofolu/demo-dashboard  -- streamlit run app/dashboard.py secondary mysql
kubectl expose deployment mysql-secondary-dashboard --port=8080 --target-port=8501 --name=mysql-secondary-dashboard-svc --type=LoadBalancer

watch kubectl get deployment -l dashboard
# (NOTE: If on AWS, change the timeout settings for the LoadBalancers to 3600)
```

#### Test Dashboard locally
```
rm -rf $(pipenv --venv)
pipenv install
pipenv shell
python -m streamlit run app/dashboard.py 'primary' 'oracle'
```

#### Sample Test Gemfire Adhoc query
```
python -m app.random_claim_generator -1 -1 http://35.227.104.221:7070/gemfire-api/v1/claims
```
