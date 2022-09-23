#!/usr/bin/env bash

BRANCH='master'

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--name)
      APP_NAME="$2"
      shift # past argument
      shift # past value
      ;;
    -b|--branch)
      BRANCH="$2"
      shift # past argument
      shift # past value
      ;;
  esac
done

echo "APP_NAME=$APP_NAME"
echo "BRANCH=$BRANCH"

mkdir build/
cd build/

# clone service repository
git clone --branch $BRANCH --single-branch git@github.com:emilhornlund/k3s-$APP_NAME.git $APP_NAME/

cd $APP_NAME/

DOCKER_REPO="registry.cluster.local:5000"
echo "DOCKER_REPO=$DOCKER_REPO"

DOCKER_IMAGE_NAME="emilhornlund/$APP_NAME"
echo "DOCKER_IMAGE_NAME=$DOCKER_IMAGE_NAME"

DOCKER_TAG=$(echo $RANDOM | md5sum | head -c 20; echo;)
echo "DOCKER_TAG=$DOCKER_TAG"

sudo docker build -t $DOCKER_IMAGE_NAME:$DOCKER_TAG .
sudo docker tag $DOCKER_IMAGE_NAME:$DOCKER_TAG $DOCKER_REPO/$DOCKER_IMAGE_NAME:$DOCKER_TAG
sudo docker push $DOCKER_REPO/$DOCKER_IMAGE_NAME:$DOCKER_TAG
sudo docker system prune -f

cd ../

# clone deployment repository
git clone --branch master --single-branch git@github.com:emilhornlund/k3s-deployments.git k3s-deployments/

cd k3s-deployments/

mkdir -p namespaces/default/apps/$APP_NAME/generated

APP_PATH_PREFIX=$(echo "$APP_NAME" | sed 's/-/_/g')
echo "APP_PATH_PREFIX=$APP_PATH_PREFIX"

APP_DOCKER_IMAGE=$DOCKER_REPO/$DOCKER_IMAGE_NAME:$DOCKER_TAG
echo "APP_DOCKER_IMAGE=$APP_DOCKER_IMAGE"

GENERATED_DEPLOYMENT_TEMPLATE_PATH="templates/backend-template.yaml"
GENERATED_DEPLOYMENT_OUTPUT_PATH="namespaces/default/apps/"$APP_NAME"/generated/"$APP_NAME"-generated.yaml"

sed -u \
    -e "s/{{APP_NAME}}/$APP_NAME/g" \
    -e "s/{{APP_PATH_PREFIX}}/$APP_PATH_PREFIX/g" \
    -e "s|{{APP_DOCKER_IMAGE}}|$APP_DOCKER_IMAGE|g" \
    "$GENERATED_DEPLOYMENT_TEMPLATE_PATH" > "$GENERATED_DEPLOYMENT_OUTPUT_PATH"

echo "Generated deployment written to $GENERATED_DEPLOYMENT_OUTPUT_PATH"

git add namespaces/default/apps/"$APP_NAME"/generated/"$APP_NAME"-generated.yaml
git commit -m "Promote $APP_NAME"
git push

kubectl apply -f namespaces/default/apps/"$APP_NAME"/generated/"$APP_NAME"-generated.yaml

cd ../../

echo "Cleaning up"
rm -rf build/

echo "Success"
