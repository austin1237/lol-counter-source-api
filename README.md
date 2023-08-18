# lol-counter-source-api
An api/on demand webscraber that collects league of legends counter data.

## Why is this lambda using a container deployment rather than the standard zip deployment?
[Pupeteer](https://pptr.dev/) requires a chrome/chromium binary which execeeded the standard [lambda size limit](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html#function-configuration-deployment-and-execution). Using a container image greatly increases the limit and allows for the binary to be deployed. Also setting up a container image seemed less janky than using a layer. Currently this service uses (@sparticuz/chromium)[https://github.com/Sparticuz/chromium] due to the standard pupeeteer install comming across permissions issues when running in the deployed aws env.

## Prerequisites
You must have the following installed/configured on your system for this to work correctly<br />
1. [Docker](https://www.docker.com/community-edition)
2. [Docker-Compose](https://docs.docker.com/compose/)

## Environment Variables
The following variables need to be set on your local/ci system.
### BASE_COUNTER_URL
Url of the website that will be scraped


## Development Environment
The development enviroment uses [aws's node 18 image](https://gallery.ecr.aws/lambda/nodejs) to mimic as close to what gonna be running when deployed as possible

### Start up
To build the lambdas and spin up the distributed development environment run the following command

```bash
docker-compose up
```

The output is similar to what you would see in cloudwatch logs ex..

```bash
lol-counter-source-api-puppeteer-lambda-1  | 18 Aug 2023 09:47:04,515 [INFO] (rapid) exec '/var/runtime/bootstrap' (cwd=/var/task, handler=)
```

The endpoint of the local container is localhost:3000/2015-03-31/functions/function/invocations send a POST request with the following body
```json
{
    "queryStringParameters": {
	"champion": "swain"
}}
```
And you should see the following response
```json
{
	"statusCode": 200,
	"headers": {},
	"body": "{\"champions\":[\"Seraphine\",\"Heimerdinger\",\"Soraka\",\"Morgana\",\"Lulu\",\"Sona\",\"Nami\",\"Janna\",\"Karma\",\"Zyra\"],\"winRates\":[\"60.58% WR\",\"60.42% WR\",\"57.56% WR\",\"55.9% WR\",\"55.52% WR\",\"54.55% WR\",\"54.09% WR\",\"53.99% WR\",\"53.99% WR\",\"53.97% WR\"]}",
	"isBase64Encoded": false
}
```

## Deployment
Deployment currently uses [Terraform](https://www.terraform.io/) to set up AWS services.
### Prerequisites
As of the time of writing there seems to be a lack of support for lambdas to us container images from public ecr repos. Instead it seems to require a private [Amazon ECR repo](https://us-east-1.console.aws.amazon.com/ecr/repositories?region=us-east-1) in the same region that the lambda is deployed to (in our case us-east-1). Name the private repo lol-counter-source 

### Setting up remote state
Terraform has a feature called [remote state](https://www.terraform.io/docs/state/remote.html) which ensures the state of your infrastructure to be in sync for mutiple team members as well as any CI system.

This project **requires** this feature to be configured. To configure **USE THE FOLLOWING COMMAND ONCE PER TEAM**.

```bash
cd terraform/remote-state terraform
terraform init
terraform apply
```


