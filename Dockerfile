FROM registry.cn-hangzhou.aliyuncs.com/jjstudy/airflow:2.1.3.9
RUN pip install --no-cache-dir apache-airflow-providers-cncf-kubernetes~=4.4.0
