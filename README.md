# PrescriptionDrugTracking

A pharmaceutical supply chain tracking system preventing counterfeit drugs and ensuring proper storage conditions from manufacturer to patient using blockchain technology.

## Overview

The PrescriptionDrugTracking system addresses the critical challenge of pharmaceutical counterfeiting and improper storage conditions throughout the supply chain. By leveraging blockchain technology, this platform provides complete transparency and traceability from drug manufacturing to patient delivery, ensuring authenticity and maintaining proper storage conditions.

## Real-World Impact

The FDA's Drug Supply Chain Security Act requires comprehensive tracking of pharmaceutical products. This blockchain implementation provides the necessary infrastructure for complete transparency, addressing the $200+ billion annual loss due to counterfeit drugs globally.

## Key Features

### 🔒 Drug Authentication
- Unique digital identifiers for all pharmaceutical products
- Immutable records of drug manufacturing and batch information
- Real-time authenticity verification at any point in the supply chain

### 📍 Supply Chain Tracking
- Complete visibility of drug movement through distribution channels
- Automated alerts for unauthorized route deviations
- Integration with existing pharmaceutical distribution systems

### 🌡️ Storage Condition Monitoring
- Continuous monitoring of temperature and humidity conditions
- Automated compliance reporting for regulatory requirements
- Immediate alerts for storage condition violations

### 📊 Transparency & Compliance
- Immutable audit trails for regulatory compliance
- Real-time reporting capabilities for stakeholders
- Integration with FDA and international regulatory frameworks

## System Architecture

The platform consists of three core smart contracts:

1. **Drug Registry Contract** - Records authentic pharmaceutical products with unique identifiers
2. **Supply Tracker Contract** - Tracks drug movement through distribution channels
3. **Authenticity Verifier Contract** - Verifies drug authenticity and proper storage conditions

## Smart Contracts

### Drug Registry (`drug-registry.clar`)
Manages the registration and authentication of pharmaceutical products, maintaining a comprehensive database of legitimate drugs with their unique identifiers and manufacturing details.

### Supply Tracker (`supply-tracker.clar`)
Handles the tracking of drug movement throughout the supply chain, recording each transfer point and ensuring proper chain of custody documentation.

### Authenticity Verifier (`authenticity-verifier.clar`)
Provides verification services for drug authenticity and monitors storage conditions, ensuring compliance with pharmaceutical safety standards.

## Benefits

- **Patient Safety**: Ensures only authentic drugs reach patients
- **Regulatory Compliance**: Automated compliance with FDA requirements
- **Cost Reduction**: Reduces losses from counterfeit drugs
- **Transparency**: Complete visibility for all stakeholders
- **Efficiency**: Streamlined verification processes

## Technology Stack

- **Blockchain**: Stacks blockchain for immutable record keeping
- **Smart Contracts**: Clarity language for secure contract execution
- **Development**: Clarinet for testing and deployment

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Git

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/koladematanmi20/PrescriptionDrugTracking.git
   cd PrescriptionDrugTracking
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run contract checks:
   ```bash
   clarinet check
   ```

4. Run tests:
   ```bash
   clarinet test
   ```

## Usage

The system supports the following key operations:

1. **Drug Registration**: Pharmaceutical manufacturers register new products
2. **Supply Chain Tracking**: Distributors and pharmacies record drug transfers
3. **Authenticity Verification**: Healthcare providers verify drug authenticity
4. **Storage Monitoring**: Continuous monitoring of storage conditions

## Contributing

We welcome contributions to improve the PrescriptionDrugTracking system. Please read our contributing guidelines and ensure all tests pass before submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions and support, please open an issue in the GitHub repository or contact the development team.

---

**Note**: This system is designed for regulatory compliance and patient safety. All implementations should be thoroughly tested and reviewed before production deployment.