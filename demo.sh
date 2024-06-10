#!/bin/bash

# Read token, UUID, and version from meta1.csv file
META1_CSV="/install/framework/bin/meta1.csv"
REPORT_FILE="/install/framework/bin/pipeline_report.txt"

# Initialize the report file
echo "Pipeline Execution Report" > "$REPORT_FILE"
echo "=========================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"


if [ -f "$META1_CSV" ]; then
    echo "Reading token, UUID, and version from meta1.csv file:"

    # Loop over each line in the CSV file
    tail -n +2 "$META1_CSV" | while IFS=',' read -r Application Name UUID Token Version; do
        echo "Executing pipeline for $Application - $Name..."
        
        # Remove leading and trailing spaces from variables
        UUID=$(echo "$UUID" | tr -d '[:space:]')
        Token=$(echo "$Token" | tr -d '[:space:]')
        Version=$(echo "$Version" | tr -d '[:space:]')

        # Execute pipeline
        EXECUTION_RESULT=$(curl --location --request POST "http://192.168.1.141:8080/framework/dag/execute?uuid=$UUID&version=$Version" \
            --header "token: $Token" \
            --header "Authorization: Bearer $Token" \
            --header "Cookie: JSESSIONID=6B68BC4306F7380D2657AC435596ABF7")

        # Check if POST request was successful
        if [ $? -eq 0 ]; then
            echo "Pipeline execution successful for $Application - $Name."
            echo "$EXECUTION_RESULT"

            # Extracting the new UUID and version from the execution result
            NEW_UUID=$(echo "$EXECUTION_RESULT" | jq -r '.ref.uuid')
            NEW_VERSION=$(echo "$EXECUTION_RESULT" | jq -r '.ref.version')

            # Check if new UUID and version are empty
            if [ -z "$NEW_UUID" ] || [ -z "$NEW_VERSION" ]; then
                echo "Error: Failed to extract new UUID or version."
                exit 1
            fi

            echo "New UUID: $NEW_UUID"
            echo "New Version: $NEW_VERSION"

            # Continuously check pipeline status until it reaches "COMPLETED" stage
            while true; do
                STATUS_RESULT=$(curl --location "http://192.168.1.141:8080/framework/dag/getStatusByDagExec?action=view&DagExecUuid=$NEW_UUID&token=$Token" \
                    --header "Authorization: Bearer $Token" \
                    --header "Cookie: JSESSIONID=844A6ADFF82D903DA11061051EE52207")

                # Check if status request was successful
                if [ $? -eq 0 ]; then
                    echo "Pipeline status fetched successfully:"
#                    echo "$STATUS_RESULT"

                    # Extract the latest status stage
                    LATEST_STATUS=$(echo "$STATUS_RESULT" | jq -r '.status | if type == "array" then .[-1].stage else . end')

                    # Check if the latest status stage is "COMPLETED"
                    if [ "$LATEST_STATUS" = "COMPLETED" ]; then
                        echo "Pipeline completed successfully for $Application - $Name."
                        break  # Break out of the loop
                    elif [ "$LATEST_STATUS" = "FAILED" ]; then
                        echo "Pipeline failed for $Application - $Name."
                        break  # Break out of the loop
                    elif [ "$LATEST_STATUS" = "TERMINATED" ]; then
                        echo "Pipeline terminated for $Application - $Name."
                        break  # Break out of the loop
                    elif [ "$LATEST_STATUS" = "KILLED" ]; then
                        echo "Pipeline killed for $Application - $Name."
                        echo "$Application - $Name: <STATUS>" >> "$REPORT_FILE"
			break  # Break out of the loop
                    else
                       echo "Pipeline is still running for $Application - $Name. Current status: $LATEST_STATUS. Waiting for completion..."
                      # echo -e "\033[1;34m\033[5mPipeline completed successfully for $Application - $Name.\033[0m" 
                      sleep 10  # Wait for 10 seconds before checking again
                    fi
                else
                    echo "Error: Failed to fetch pipeline status."
                    exit 1
                fi
            done
        else
            echo "Error: Failed to execute pipeline for $Application - $Name."
            exit 1
        fi
    done
else
    echo "Error: meta1.csv file not found."
    exit 1
fi
