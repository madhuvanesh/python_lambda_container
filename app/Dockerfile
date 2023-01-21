FROM public.ecr.aws/lambda/python:3.9

# Install the function's dependencies using file requirements.txt
# from your project folder.

COPY requirements.txt  .
RUN  pip install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"
RUN mkdir -p /tmp/matplotlib
ENV MPLCONFIGDIR /tmp/matplotlib
# Copy function code
COPY app.py ${LAMBDA_TASK_ROOT}

RUN echo "The $ENLAMBDA_TASK_ROOT variable is $LAMBDA_TASK_ROOT"
RUN echo "The ENV variable MPLCONFIGDIR is $MPLCONFIGDIR"

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "app.handler" ] 