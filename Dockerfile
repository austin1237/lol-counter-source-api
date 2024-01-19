FROM public.ecr.aws/lambda/nodejs:18.2023.08.17.15

# Copy package.json and package-lock.json
COPY package*.json ${LAMBDA_TASK_ROOT}/

# Install dependencies
RUN npm install

# Copy function code
COPY index.js ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "index.handler" ]