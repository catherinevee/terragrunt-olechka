# Infrastructure Overview Diagram

## Complete System Architecture

```mermaid
graph TB
    subgraph "Developer Workflow"
        DEV[Developer]
        GIT[Git Push]
    end

    subgraph "GitHub"
        REPO[GitHub Repository<br/>terragrunt-olechka]
        ACTIONS[GitHub Actions<br/>CI/CD Pipeline]
        SECRETS[Repository Secrets<br/>& Variables]
    end

    subgraph "CI/CD Pipeline Stages"
        direction LR
        DETECT[1. Detect Changes]
        VALIDATE[2. Validate<br/>- Format<br/>- Lint<br/>- Security]
        PLAN[3. Plan<br/>Generate tfplan]
        REVIEW{4. Review<br/>Manual/Auto}
        APPLY[5. Apply<br/>Deploy Infrastructure]
    end

    subgraph "AWS Account (025066254478)"
        subgraph "IAM & Security"
            OIDC[OIDC Provider<br/>GitHub]
            ROLE[github-actions-role]
        end

        subgraph "Terraform Backend"
            S3[S3 State Bucket<br/>terraform-state-*]
            DYNAMO[DynamoDB<br/>Lock Table]
        end

        subgraph "Deployed Infrastructure"
            subgraph "Network"
                VPC[VPC + Subnets]
                ALB[Load Balancer]
            end

            subgraph "Compute"
                ECS[ECS Fargate<br/>API + Worker]
            end

            subgraph "Data"
                RDS[Aurora PostgreSQL]
                S3DATA[S3 Buckets]
                CACHE[ElastiCache]
            end

            subgraph "Security"
                KMS[KMS Encryption]
                SM[Secrets Manager]
                WAF[WAF Rules]
            end

            subgraph "Monitoring"
                CW[CloudWatch]
                XRAY[X-Ray Tracing]
            end
        end
    end

    %% Workflow connections
    DEV --> GIT
    GIT --> REPO
    REPO --> ACTIONS
    ACTIONS --> DETECT
    DETECT --> VALIDATE
    VALIDATE --> PLAN
    PLAN --> REVIEW
    REVIEW -->|Approved| APPLY

    %% AWS connections
    ACTIONS -.->|OIDC Auth| OIDC
    OIDC --> ROLE
    ROLE --> S3
    ROLE --> DYNAMO
    APPLY --> VPC
    APPLY --> ECS
    APPLY --> RDS
    APPLY --> KMS

    %% Infrastructure connections
    ALB --> ECS
    ECS --> RDS
    ECS --> S3DATA
    ECS --> CACHE
    ECS --> SM
    SM --> KMS
    ECS --> CW
    ECS --> XRAY
    ALB --> WAF

    %% Secrets flow
    SECRETS -.->|Variables| ACTIONS

    classDef github fill:#f0f0f0,stroke:#24292e,stroke-width:2px
    classDef pipeline fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef aws fill:#ff9900,stroke:#232f3e,color:#fff,stroke-width:2px
    classDef infra fill:#146eb4,stroke:#232f3e,color:#fff,stroke-width:2px
    classDef security fill:#d13212,stroke:#232f3e,color:#fff,stroke-width:2px

    class DEV,GIT,REPO,ACTIONS,SECRETS github
    class DETECT,VALIDATE,PLAN,REVIEW,APPLY pipeline
    class OIDC,ROLE,S3,DYNAMO aws
    class VPC,ALB,ECS,RDS,S3DATA,CACHE infra
    class KMS,SM,WAF,CW,XRAY security
```

## Workflow Execution Example

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GHA as GitHub Actions
    participant AWS as AWS (OIDC)
    participant TF as Terraform/Terragrunt
    participant Infra as Infrastructure

    Dev->>GH: Push code to main
    GH->>GHA: Trigger workflow

    rect rgb(240, 240, 240)
        Note over GHA: Stage 1: Detection
        GHA->>GHA: Detect changed files
        GHA->>GHA: Create job matrix
    end

    rect rgb(225, 245, 254)
        Note over GHA: Stage 2: Validation
        GHA->>AWS: Authenticate via OIDC
        AWS-->>GHA: Temporary credentials

        par Format Check
            GHA->>TF: terragrunt fmt
        and Validate
            GHA->>TF: terragrunt validate
        and Security Scan
            GHA->>GHA: Run Checkov
        and Cost Analysis
            GHA->>GHA: Run Infracost
        end
    end

    rect rgb(255, 243, 224)
        Note over GHA: Stage 3: Planning
        GHA->>TF: terragrunt init
        TF->>AWS: Get state from S3
        AWS-->>TF: Current state
        GHA->>TF: terragrunt plan
        TF-->>GHA: Plan output
        GHA->>GH: Comment on PR (if applicable)
    end

    rect rgb(232, 245, 233)
        Note over GHA: Stage 4: Apply (if main)
        GHA->>GHA: Check environment
        alt Production
            GHA->>Dev: Request approval
            Dev-->>GHA: Approve
        end
        GHA->>TF: terragrunt apply
        TF->>AWS: Lock state (DynamoDB)
        TF->>Infra: Create/Update resources
        Infra-->>TF: Success
        TF->>AWS: Update state (S3)
        TF->>AWS: Release lock
        TF-->>GHA: Apply complete
    end

    GHA->>Dev: Notify success (Slack)
```

## Environment-Specific Configuration

```mermaid
graph LR
    subgraph "Configuration Hierarchy"
        ROOT[Root terragrunt.hcl<br/>- Backend config<br/>- Provider generation]

        subgraph "Environment Layer"
            DEV_CFG[dev/<br/>account.hcl<br/>env.hcl]
            STAGE_CFG[staging/<br/>account.hcl<br/>env.hcl]
            PROD_CFG[production/<br/>account.hcl<br/>env.hcl]
        end

        subgraph "Region Layer"
            EU[eu-central-1/<br/>region.hcl]
            AP[ap-southeast-1/<br/>region.hcl]
        end

        subgraph "Shared Configs"
            COMMON[_envcommon/<br/>- network.hcl<br/>- compute.hcl<br/>- storage.hcl<br/>- monitoring.hcl]
        end

        subgraph "Module Configs"
            MODULES[infrastructure modules<br/>vpc/terragrunt.hcl<br/>ecs/terragrunt.hcl<br/>etc...]
        end
    end

    ROOT --> DEV_CFG
    ROOT --> STAGE_CFG
    ROOT --> PROD_CFG

    DEV_CFG --> EU
    DEV_CFG --> AP

    EU --> MODULES
    AP --> MODULES

    COMMON --> MODULES

    subgraph "Resulting Infrastructure"
        subgraph "Dev Environment"
            DEV_INFRA[- Single NAT Gateway<br/>- Spot Instances<br/>- 7 day backups<br/>- Minimal HA]
        end

        subgraph "Staging Environment"
            STAGE_INFRA[- Multi-AZ NAT<br/>- On-demand instances<br/>- 14 day backups<br/>- Partial HA]
        end

        subgraph "Production Environment"
            PROD_INFRA[- Full HA (Multi-AZ)<br/>- Reserved instances<br/>- 30 day backups<br/>- Cross-region replication]
        end
    end

    MODULES --> DEV_INFRA
    MODULES --> STAGE_INFRA
    MODULES --> PROD_INFRA

    classDef config fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef env fill:#e0f2f1,stroke:#00695c,stroke-width:2px
    classDef result fill:#fff3e0,stroke:#e65100,stroke-width:2px

    class ROOT,COMMON,MODULES config
    class DEV_CFG,STAGE_CFG,PROD_CFG,EU,AP env
    class DEV_INFRA,STAGE_INFRA,PROD_INFRA result
```

## Key Metrics and Monitoring

```mermaid
graph TB
    subgraph "Metrics Collection"
        APP[Application Metrics]
        INFRA[Infrastructure Metrics]
        CUSTOM[Custom Metrics]
    end

    subgraph "CloudWatch"
        LOGS[Log Groups<br/>- /ecs/ai-tools-api<br/>- /ecs/ai-tools-worker]
        METRICS[Metrics<br/>- CPU/Memory<br/>- Request rates<br/>- Error rates]
        ALARMS[Alarms<br/>- High CPU > 75%<br/>- Error rate > 2%<br/>- Latency > 1s]
    end

    subgraph "X-Ray"
        TRACE[Distributed Tracing]
        MAP[Service Map]
        PERF[Performance Analysis]
    end

    subgraph "Alerting"
        SNS[SNS Topics]
        SLACK[Slack Notifications]
        EMAIL[Email Alerts]
    end

    subgraph "Dashboards"
        EXEC[Executive Dashboard<br/>- Service health<br/>- Cost overview]
        OPS[Operations Dashboard<br/>- Real-time metrics<br/>- Error tracking]
        DEV[Developer Dashboard<br/>- API performance<br/>- Trace analysis]
    end

    APP --> LOGS
    INFRA --> METRICS
    CUSTOM --> METRICS

    METRICS --> ALARMS
    ALARMS --> SNS
    SNS --> SLACK
    SNS --> EMAIL

    APP --> TRACE
    TRACE --> MAP
    MAP --> PERF

    LOGS --> OPS
    METRICS --> EXEC
    PERF --> DEV

    classDef collect fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef process fill:#f3e5f5,stroke:#6a1b9a,stroke-width:2px
    classDef alert fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef visual fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px

    class APP,INFRA,CUSTOM collect
    class LOGS,METRICS,ALARMS,TRACE,MAP,PERF process
    class SNS,SLACK,EMAIL alert
    class EXEC,OPS,DEV visual
```