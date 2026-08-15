# Implementation Notes

## Real-World Insights and Lessons Learned

### Network Design Considerations

#### Topology Planning
- Start with simple topology (2 sites) before scaling to 4+
- Plan IP addressing carefully to avoid overlaps
- Reserve addresses for future expansion
- Document all IP ranges in central location

#### Redundancy Planning
- Design for single-link failures
- Consider redundant VPN connections to AWS
- Plan for router/device failures
- Test failover scenarios regularly

### OSPF Implementation Lessons

#### Router ID Assignment
- Use loopback addresses as router IDs (more stable)
- Manually configure router IDs rather than relying on auto-selection
- Ensure router IDs are unique across entire domain

```
Example: Use 1.1.1.1 for Site1, 2.2.2.2 for Site2, etc.
```

#### Area Design
- In small deployments, use single area (area 0) for simplicity
- Large networks benefit from multi-area design
- Avoid area 0 only configurations
- Consider stub/totally stubby areas for edge sites

#### Convergence Optimization
- Default OSPF timers work for most scenarios
- Aggressive timers (hello=3s, dead=10s) improve convergence but increase CPU
- Test before deploying aggressive timers in production
- Use BFD for sub-second detection in critical links

### BGP Implementation Lessons

#### Route Summarization
- Always use aggregate-address to summarize site networks
- Reduces BGP table size and improves stability
- Configure with summary-only for cleaner route advertisement

```
aggregate-address 10.0.0.0 255.0.0.0 summary-only
```

#### AS Path Manipulation
- Use prepending sparingly (adds 1-2 prepends, not 10+)
- Document all route policies for maintenance
- Test route changes in lab before deploying to production

#### Route Dampening
- Enable dampening for unstable routes
- Default parameters usually sufficient
- Monitor dampened routes: `show ip bgp dampening`

### IPSec VPN Implementation Lessons

#### Phase 1 (IKE) Configuration
- Use DH group 2 for compatibility with AWS
- SHA1 acceptable for lab; use SHA256 for production
- Pre-shared keys should be 32+ characters, random
- Store PSKs securely, never in version control

#### Phase 2 (IPSec) Configuration
- AES-256 provides strong encryption
- ESP mode tunnel recommended for site-to-site
- Perfect Forward Secrecy (PFS) enables in Phase 2
- Rekey time 3600s (1 hour) is standard

#### MTU and Fragmentation
- Always set tunnel MTU to 1436 bytes
- Enables 1500-byte packets with IPSec overhead
- Enable MSS clamping: `ip tcp adjust-mss 1379`
- Test large file transfers to verify MTU

#### VPN Monitoring
- Use continuous ping to monitor tunnel health
- Set up syslog alerts for tunnel down events
- Regularly review crypto statistics
- Test failover to backup tunnel at least monthly

### AWS Integration Lessons

#### VPN Connection Setup
- Download Cisco-specific configuration from AWS
- Pre-shared key generation should be done on AWS side
- Save all AWS configuration details in secure location
- Test connectivity immediately after setup

#### Route Propagation
- Enable route propagation to propagate VPN routes to route tables
- Understand difference between dynamic (BGP) and static routes
- Test AWS-side route modifications
- Monitor route table for unexpected changes

#### Security Considerations
- Use Security Groups to restrict traffic
- Implement NACLs for additional filtering
- Enable VPC Flow Logs for traffic analysis
- Regular security audits of VPN configuration

### Operational Best Practices

#### Change Management
1. Always test configuration changes in lab first
2. Document all changes with date and rationale
3. Create backup before major changes
4. Schedule changes during maintenance windows
5. Have rollback plan documented

#### Monitoring Strategy
- Set up SNMP monitoring for key metrics
- Configure syslog for centralized logging
- Alert on critical conditions (tunnel down, OSPF/BGP flaps)
- Regular review of logs and statistics

#### Documentation
- Keep as-built documentation updated
- Document deviations from standard configuration
- Maintain change log
- Keep network diagrams current
- Store credentials securely

#### Testing Procedures
- Test failover scenarios quarterly
- Perform load testing annually
- Test disaster recovery procedures
- Validate configuration backups
- Test security policies regularly

### Troubleshooting Approach

#### Methodology
1. Gather information: `show` commands, logs
2. Identify affected components
3. Test hypothesis with targeted commands
4. Make single change at a time
5. Verify change had desired effect
6. Document resolution for future reference

#### Tools and Commands
- Always start with: `show ip route`, `show ip bgp`, `show crypto session`
- Use `debug` commands carefully (can impact performance)
- Enable conditional debugging for specific protocols
- Disable debug immediately after troubleshooting

### Performance Tuning

#### CPU Optimization
- Monitor CPU usage with `show processes`
- Avoid excessive debug output on production
- Optimize BGP dampening parameters
- Use per-packet load balancing for high throughput

#### Memory Optimization
- Monitor memory with `show memory`
- Clear unused routes regularly
- Archive old logs
- Monitor BGP table growth

#### Throughput Optimization
- Enable hardware offloading if available
- Optimize MTU settings
- Use proper QoS policies
- Monitor link utilization

### Common Mistakes to Avoid

1. **Not Testing Changes** - Always lab test first
2. **Overlapping IP Addresses** - Use proper planning
3. **Mismatched PSKs** - Double-check both ends
4. **Aggressive Timers** - Test before deploying
5. **Poor Documentation** - Keep detailed notes
6. **No Backups** - Save running-config frequently
7. **Ignoring Logs** - Review logs regularly
8. **Tunnel Asymmetry** - Verify bidirectional traffic

### Advanced Techniques

#### BFD for Fast Failure Detection
```
interface fa0/0
 bfd interval 100 min_rx 100 multiplier 3
router ospf 1
 bfd all-interfaces
```

#### NHRP for DMVPN (Advanced)
- Can replace mesh topology with dynamic spoke connectivity
- More complex but supports larger topologies
- Future enhancement for this project

#### Traffic Engineering with BGP
- Use local preference for path control
- Use MED for AS-exit selection
- Use AS path prepending for fine-tuning

### Security Hardening

1. **Access Control Lists**
   - Restrict management access
   - Limit OSPF/BGP to authorized routers

2. **Routing Security**
   - MD5 authentication for BGP neighbors
   - OSPF MD5 authentication on all links

3. **VPN Security**
   - Regularly rotate pre-shared keys
   - Monitor for suspicious VPN attempts
   - Enable DPD for stale tunnel cleanup

4. **Physical Security**
   - Keep configuration backups offline
   - Secure storage of documentation
   - Access control to network devices

### Future Enhancements

1. **Redundant VPN Connections**
   - Multiple tunnels to AWS for HA
   - Active-active or active-passive design

2. **MPLS Implementation**
   - Traffic engineering capabilities
   - More efficient label switching

3. **Advanced BGP Policies**
   - Community-based filtering
   - Complex route manipulation

4. **QoS Enhancement**
   - Per-application traffic shaping
   - Priority queuing for business-critical apps

5. **Monitoring and Analytics**
   - Netflow/sFlow implementation
   - Real-time traffic analysis

---

**Last Updated:** August 2026
**Author:** Network Engineering Lab
