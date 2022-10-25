FROM 202.168.130.15/airflow/airflow:2.1.3.9
RUN pip install --no-cache-dir apache-airflow-providers-cncf-kubernetes~=4.4.0
