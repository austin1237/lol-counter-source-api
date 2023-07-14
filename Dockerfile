FROM public.ecr.aws/lambda/nodejs:18

# Copy package.json and package-lock.json
COPY package*.json ${LAMBDA_TASK_ROOT}

# Install dependencies
RUN npm install

# Copy function code
COPY index.js ${LAMBDA_TASK_ROOT}

# Create a directory inside the container
RUN mkdir ${LAMBDA_TASK_ROOT}/src
COPY ./src ${LAMBDA_TASK_ROOT}/src

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "index.handler" ]