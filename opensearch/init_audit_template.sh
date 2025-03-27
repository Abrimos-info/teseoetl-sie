   #!/bin/bash
   #This script runs on every init of opensearch, but it's actually only for the first run of a cluster
   set -x
   # Wait for OpenSearch to be ready
   until curl -k -s -o /dev/null -w "%{http_code}" $OPENSEARCH_URL | grep -q "200"; do
     echo "Waiting for OpenSearch..."
     sleep 5
   done

   # Check if the template already exists
   if ! curl -k -s -o /dev/null -w "%{http_code}" "$OPENSEARCH_URL/_index_template/audit_body_terms_template" | grep -q "200"; then
   echo "Updating default theme and route..."
   curl -k -X POST "$OPENSEARCH_URL/.kibana*/_update_by_query" -H 'Content-Type: application/json' -d '{
      "query": {
        "term": {
          "type": {
            "value": "config"
          }
        }
      },
      "script": {
        "source": "ctx._source['"'"'theme:version'"'"'] = params.themeVersion; ctx._source['"'"'defaultRoute'"'"'] = params.defaultRoute;",
        "lang": "painless",
        "params": {
          "themeVersion": "v9",
          "defaultRoute": "/app/discover"
        }
      }
    }'

   echo "Creating pipeline for audit body terms..."
   curl -k -X PUT "$OPENSEARCH_URL/_ingest/pipeline/audit_body_terms_pipeline" -H 'Content-Type: application/json' -d '{
    "description": "Advanced termino extraction with multiple property handling",
    "processors": [
      {
        "json": {
          "field": "audit_request_body",
          "target_field": "_json",
          "on_failure": [
            {
              "set": {
                "field": "processing_error",
                "value": "Failed to parse JSON: {{ _ingest.on_failure_message }}"
              }
            }
          ]
        }
      },
      {
        "script": {
          "lang": "painless",
          "source": "// Define the property configurations\ndef propertyConfig = [\n  ['"'"'path'"'"': '"'"'query.bool.filter.must_not.match_phrase'"'"'],\n  ['"'"'path'"'"': '"'"'query.bool.filter.multi_match.query'"'"'],\n  ['"'"'path'"'"': '"'"'query.bool.range'"'"'],\n  ['"'"'path'"'"': '"'"'query.bool.filter.must.match_phrase'"'"'],\n  ['"'"'path'"'"': '"'"'query.bool.filter.must.term'"'"'],\n  ['"'"'path'"'"': '"'"'query.bool.must.term'"'"'],\n  ['"'"'path'"'"': '"'"'query.bool.must.simple_query_string.query'"'"'],\n  ['"'"'path'"'"': '"'"'query.term'"'"'],\n  ['"'"'path'"'"': '"'"'query.match'"'"'],\n  ['"'"'path'"'"': '"'"'query.match_phrase'"'"'],\n  ['"'"'path'"'"': '"'"'query.bool.filter.match_phrase'"'"']\n];\nctx._debug = \"\";\ndef foundValues = [];\n\n// Find all available values\nfor (def config : propertyConfig) {\n  def keys = new ArrayList();\n  def path = config.get('"'"'path'"'"');\n  int start = 0;\n  int delimiterIndex;\n  \n  // Split the path into keys\n  while ((delimiterIndex = path.indexOf('"'"'.'"'"', start)) != -1) {\n      keys.add(path.substring(start, delimiterIndex));\n      start = delimiterIndex + 1;\n  }\n  keys.add(path.substring(start));\n  \n  // Navigate through the JSON structure\n  def current = ctx._json;\n  def value = null;\n  \n  for (def key : keys) {\n    if (current == null) {\n      break;\n    }\n    \n    if (current instanceof List) {\n      def results = new ArrayList();\n      for (def item : current) {\n        if (item instanceof Map) {\n          def tempValue = item.get(key);\n          if (tempValue != null) {\n            results.add(tempValue);\n          }\n        }\n      }\n      if (results.size() > 0) {\n        current = results;\n        value = results;\n      } else {\n        current = null;\n        value = null;\n      }\n    } else if (current instanceof Map) {\n      current = current.get(key);\n      value = current;\n    } else {\n      current = null;\n      value = null;\n      break;\n    }\n  }\n  \n  ctx._debug += path + \"=\" + value + \" | \";\n\n  if (value != null) {\n    if (value instanceof List && value.size() > 0) {\n      value = value[0];\n    }\n    \n    // Always trim the value\n    value = value.toString().trim();\n    \n    def foundValue = new HashMap();\n    foundValue.put(\"value\", value);\n    foundValue.put(\"source\", config.get(\"path\"));\n    foundValues.add(foundValue);\n  }\n}\n\n// Store all found values\nif (foundValues.size() > 0) {\n  ctx.terminos = foundValues;\n} else {\n  ctx.processing_error = \"No valid value found in any of the expected properties\";\n}\n\nctx.remove('"'"'_json'"'"');"
        }
      }
    ]
  }'


   echo "Creating template for security-audit-* pattern..."
   curl -k -X PUT "$OPENSEARCH_URL/_index_template/audit_body_terms_template" -H 'Content-Type: application/json' -d '{
     "index_patterns": ["security-audit-*"],
     "template": {
       "settings": {
         "default_pipeline": "audit_body_terms_pipeline"
       }
     }
   }'

   # Create template for opensearch-security-auditlog pattern
   echo "Creating template for opensearch-security-auditlog pattern..."
   curl -k -X PUT "$OPENSEARCH_URL/_index_template/audit_body_terms_template" -H 'Content-Type: application/json' -d '{
     "index_patterns": ["opensearch-security-auditlog*"],
     "data_stream": {},
     "priority": 500,
     "template": {
       "settings": {
         "index": {
           "default_pipeline": "audit_body_terms_pipeline"
         }
       }
     }
   }'

   # Create template for .ds-opensearch-security-auditlog pattern
  #  echo "Creating template for .ds-opensearch-security-auditlog pattern..."
  #  curl -k -X PUT "$OPENSEARCH_URL/_index_template/audit_body_terms_template" -H 'Content-Type: application/json' -d '{
  #    "index_patterns": [".ds-opensearch-security-auditlog-*"],
  #    "template": {
  #      "settings": {
  #        "index.default_pipeline": "audit_body_terms_pipeline"
  #      }
  #    }
  #  }'
  #  else
  #    echo "Data stream template already exists."
   fi



