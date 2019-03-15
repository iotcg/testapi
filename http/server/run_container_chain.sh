# Rebuild all artifacts
docker rm -f zipkin-latency prometheus-latency grafana-latency root branch leaf test 
docker network rm apinet 
docker build -t test-api-server:latest .

# Cleanup

# Docker DNS does not work with Kata (hence use explicit IP)
# Use a custom docker network so that you can control the network
docker network create apinet --subnet=192.168.211.0/24
docker run --network apinet --name=zipkin-latency -d -p 9411:9411 \
                                         -e HTTP_PROXY='' \
                                         -e http_proxy='' \
                                         -e HTTPS_PROXY='' \
                                         -e https_proxy='' \
                                         --ip 192.168.211.2 \
                                         openzipkin/zipkin

docker run --network apinet --name=prometheus-latency -d -p 9090:9090 \
        -v $PWD/prometheus_docker.yml:/etc/prometheus/prometheus.yml \
                                         -e HTTP_PROXY='' \
                                         -e http_proxy='' \
                                         -e HTTPS_PROXY='' \
                                         -e https_proxy='' \
                                         --ip 192.168.211.3 \
                                         prom/prometheus

# Import prometheus as a data source.
# Also create graphs using the formula
# histogram_quantile(0.99, sum(rate(root_opencensus_io_http_server_latency_bucket[5m])) by (le))  
# histogram_quantile(0.95, sum(rate(root_opencensus_io_http_server_latency_bucket[5m])) by (le))  
# histogram_quantile(0.90, sum(rate(root_opencensus_io_http_server_latency_bucket[5m])) by (le))  
# histogram_quantile(0.50, sum(rate(root_opencensus_io_http_server_latency_bucket[5m])) by (le))  
# This can be verified against the histogram generated by hey
docker run -d --name=grafana-latency --net=host -p 3000:3000 grafana/grafana

# Only the root container exposes the port. Downstream URIs are accessed within the container network
RUNTIME=kata
docker run --network apinet --name=root --hostname=root --runtime="$RUNTIME" -d \
                                         -e HTTP_PROXY='' \
                                         -e http_proxy='' \
                                         -e HTTPS_PROXY='' \
                                         -e https_proxy='' \
                                         -e CPU_BUSYWORK='10' \
                                         -e UPSTREAM_URI='0.0.0.0:8888' \
                                         -e DOWNSTREAM_URI='http://192.168.211.5:8888' \
                                         -e REPORTER_URI='http://192.168.211.2:9411/api/v2/spans' \
                                         -p 8888:8888 \
                                         --ip 192.168.211.4 \
                                         test-api-server:latest

docker run --network apinet --name=branch --hostname=branch --runtime="$RUNTIME" -d \
                                         -e HTTP_PROXY='' \
                                         -e http_proxy='' \
                                         -e HTTPS_PROXY='' \
                                         -e https_proxy='' \
                                         -e CPU_BUSYWORK='10' \
                                         -e UPSTREAM_URI='0.0.0.0:8888' \
                                         -e DOWNSTREAM_URI='http://192.168.211.6:8888' \
                                         -e REPORTER_URI='http://192.168.211.2:9411/api/v2/spans' \
                                         --ip 192.168.211.5 \
                                         test-api-server:latest

docker run --network apinet --name=leaf --hostname=leaf --runtime="$RUNTIME" -d \
                                         -e HTTP_PROXY='' \
                                         -e http_proxy='' \
                                         -e HTTPS_PROXY='' \
                                         -e https_proxy='' \
                                         -e CPU_BUSYWORK='10' \
                                         -e UPSTREAM_URI='0.0.0.0:8888' \
                                         -e REPORTER_URI='http://192.168.211.2:9411/api/v2/spans' \
                                         --ip 192.168.211.6 \
                                         test-api-server:latest