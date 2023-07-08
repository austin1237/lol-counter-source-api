FROM public.ecr.aws/lambda/nodejs:18

RUN yum install -y pango libXcomposite libXcursor libXdamage libXext libXi libXtst cups-libs libXScrnSaver libXrandr GConf2 alsa-lib atk gtk3 gdk-pixbuf2
RUN yum update -y

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