import boto3
import yaml

region = "ap-south-1"
output_file = "/etc/prometheus/ecs_file_sd.yml"

ecs = boto3.client("ecs", region_name=region)
ec2 = boto3.client("ec2", region_name=region)

targets = []

clusters = ecs.list_clusters()["clusterArns"]

for cluster in clusters:
    tasks = ecs.list_tasks(cluster=cluster)["taskArns"]

    if not tasks:
        continue

    task_details = ecs.describe_tasks(cluster=cluster, tasks=tasks)

    for task in task_details["tasks"]:
        for attachment in task.get("attachments", []):
            for detail in attachment.get("details", []):
                if detail["name"] == "networkInterfaceId":
                    eni_id = detail["value"]

                    eni = ec2.describe_network_interfaces(
                        NetworkInterfaceIds=[eni_id]
                    )

                    ip = eni["NetworkInterfaces"][0]["PrivateIpAddress"]

                    targets.append(f"{ip}:4000")  # ⚠️ change port

# Write YAML
data = [{"targets": targets}]

with open(output_file, "w") as f:
    yaml.dump(data, f)

print("Targets updated!")