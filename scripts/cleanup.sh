# Mandatory FinOps protocol before closing each Learner Lab session (4h):
kubectl delete svc --all -n retail
helm uninstall monitoring -n monitoring
kubectl delete pvc --all -n monitoring
cd terraform/ && terraform destroy -auto-approve