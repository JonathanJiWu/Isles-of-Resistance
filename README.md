# Isles of Resistance

## Overview
"Isles of Resistance" is a single-player turn-based defense game set in a fictional archipelago. The player defends their islands against an AI-controlled air invasion using strategic deployments on a hex-based map. The game features real-time animations, a research system, and an adaptive AI opponent.

## Features
- **Turn-based Strategy:** Player vs. AI, alternating turns.
- **Hex-based Map:** Terrain impacts movement and strategy.
- **Fog of War:** Limited visibility, reconnaissance upgrades available.
- **Resource Management:** Balance building defenses, research, and counterattacks.
- **Enemy AI:** Dynamic AI that adapts to the player’s tactics.
- **Research System:** Unlock new defenses and upgrades.
- **Real-time Battle Animations:** Graphical representation of combat, skippable for fast play.

## Technology Stack
- **Primary Language:** C++ (Game Logic, AI)
- **Frontend:** JavaScript (React for UI, animations)
- **Backend:** Python (Automation and AI enhancements)
- **Networking:** WebSockets & REST API
- **Database:** SQLite (Local for now, expandable to AWS DynamoDB)
- **Deployment:** AWS (EC2 for backend, S3 & CloudFront for frontend, Lambda for automation)
- **CI/CD:** GitHub Actions + AWS CodePipeline
- **Testing:** Google Test (C++), Jest (JavaScript)

## Installation & Setup
### Prerequisites
- C++ compiler (GCC/Clang/MSVC)
- Node.js & npm (for frontend)
- Python (for automation scripts)
- AWS CLI (if deploying to AWS)
- Git

### Clone the Repository
```sh
$ git clone https://github.com/JonathanJiWu/isles-of-resistance.git
$ cd isles-of-resistance
```

### Backend Setup
```sh
$ cd backend
$ mkdir build && cd build
$ cmake ..
$ make
$ ./game_server
```

### Frontend Setup
```sh
$ cd frontend
$ npm install
$ npm start
```

## Deployment
To deploy the backend to AWS EC2:
```sh
$ aws ec2 run-instances --image-id ami-12345678 --count 1 --instance-type t2.micro
```

To deploy the frontend to AWS S3:
```sh
$ npm run build
$ aws s3 sync build/ s3://your-s3-bucket-name
```

## Contributing
1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -m 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Open a Pull Request.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact
For any inquiries, reach out via email or open an issue on GitHub.

---
This document will evolve as development progresses, ensuring we maintain a structured approach to delivering "Isles of Resistance."

